---
layout: post
title:  "Deploy a Static Website on Kubernetes"
date:   2017-09-04 22:37:01 -0400
categories: jekyll update
---

<blockquote class="twitter-tweet" data-lang="en" data-dnt="true" data-theme="dark"><p lang="en" dir="ltr">Deployed my blog on Kubernetes <a href="https://t.co/XHXWLrmYO4">pic.twitter.com/XHXWLrmYO4</a></p>&mdash; Dex (@dexhorthy) <a href="https://twitter.com/dexhorthy/status/856639005462417409">April 24, 2017</a></blockquote> <script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

## Generate a static blog

To generate an example Jekyll blog.

    jekyll new test_blog
    cd test_blog
    jekyll build

## Build Docker Image

Add this Dockerfile in the root directory then `docker build . -t rhan888:blog`.

    FROM nginx
    EXPOSE 80
    COPY _site/ /usr/share/nginx/html

This creates a docker image from the nginx base image. Nginx serves static content from root directory under default settings and typically runs on 1mb of memory and negligible CPU.

Now upload this image to a Docker registry of your choice.

## Deploy Docker Image to Kubernetes

### Create a Pod

Create a new file named `blog-deployment.yml`. It will be used later to create an a pod on your cluster. 

    apiVersion: extensions/v1beta1
    kind: Deployment
    metadata:
      name: blog
    spec:
      replicas: 1
      template:
        spec:
          containers:
          - env:
            image: rhan888/blog:latest
            imagePullPolicy: Always
            name: blog
            ports:
            - containerPort: 80

To "run" this file, supply the file to `kubectl`.

    kubectl create -f blog-deployment.yml

Now a deployment is created on the cluster. However, it is only accessible from within the cluster.

### Create a Service

We need to expose the port and bind it an external IP. We achieve this by creating a service. The `blog-service.yml` is the configuration file for this service.

    apiVersion: v1
    kind: Service
    metadata:
      name: blog
    spec:
      type: "LoadBalancer"
      ports:
      - name: "http"
        port: 80
        targetPort: 80
      selector:
        name: blog

Supply kubernetes with the above config:

`kubectl create -f blog-service.yml`

Now your static blog is deployed on Kubernetes, up and accessible from external IP.

<!--
There are four types of service:
 
* ClusterIP: Exposes the service on a cluster-internal IP. Choosing this value makes the service only reachable from within the cluster. This is the default ServiceType.

* NodePort: Exposes the service on each Node’s IP at a static port (the NodePort). A ClusterIP service, to which the NodePort service will route, is automatically created. You’ll be able to contact the NodePort service, from outside the cluster, by requesting <NodeIP>:<NodePort>.

* LoadBalancer: Exposes the service externally using a cloud provider’s load balancer. NodePort and ClusterIP services, to which the external load balancer will route, are automatically created.

* ExternalName: Maps the service to the contents of the externalName field (e.g. foo.bar.example.com), by returning a CNAME record with its value. No proxying of any kind is set up. This requires version 1.7 or higher of kube-dns.

So for a frontend service(user-facing, as opposed to a Database or Redis), the options are `NodePort` and `LoadBalancer`, the former exposes the service port directly(think proxy_pass) and the latter distributes incoming requests to different pods. The cool thing about service is that kubernetes actually uses nginx internally. And kubernetes comes battery included: bindings with different cloud providers (i.e. GKE, AWS) so getting an external IP does not require any extra steps. In short, the developer can use the best tooling without ANY configuration. Explain why kubernetes is an overkill?

(Aside: on GCE(GKE), there is 0 charge for external IPs unless it's not used by a service)

## Optional: Add an Ingress

Don't use it on GKE. It's basically a CDN cache that charges ridiculous $$$. Its functionality is nothing more than Cloudflare free-tier.~~ According to [alpb](https://news.ycombinator.com/item?id=14287780), Ingress is not a CDN and is charged the same price as a regional load balancer (Service.type=LoadBalancer). But for AWS kubernetes users, this is a viable option if you find the need to use it, ingress is not in the scope of this blog post. For most static sites, the load balancing above is already an "overkill"(in a good way).

-->

## Conclusion

We can deploy a static website to Kubernetes with minimal effort.
