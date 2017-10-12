---
layout: post
title:  "Running Factorio on SONM"
date:   2017-10-12 00:37:02 -0400
categories: jekyll update
---


In this short post, I will test out SONM.

SONM is a decentralized cloud provider. In this case, cloud is just someone else's computer literally. I read on the website that this is called "fog computing." In essense, anyone can become a "miner" to run application in exchange for SONM tokens. The technology is enabled by Docker, Yandex Cocaine and its own network discovery module(insomnia) and a blockchain interface. There are two binaries: hub for discovery(presumably one for a computing cluster) and miner to run on each host machine, both written in Go. I'd like to think of SONM as Kubernetes on a blockchain.

To test the project at its current stage, I will deploy a Factorio docker server and judge by the ease of use for both sysadmin and end user.

# Installing SONM Toolbelt

Following alpha release [the tutorial](https://sonm.io/alpha-release/) step by step, I downloaded the 0.2.1 release from [Github](https://github.com/sonm-io/core/releases).

    $ ./sonmhub
    INFO [10-12|19:26:40] Starting P2P networking 
    INFO [10-12|19:26:42] UDP listener up                          self=enode://b1ac08dd98423379ed75a4ea28ea5f4d96896743a8648d7c20880f79378a13ef910e8e2d98c50c01fa2442d7ffd5811a3ce25650f8592aa3ee2ae10970f5b7a4@207.244.97.166:30343
    INFO [10-12|19:26:42] Whisper started 
    2017-10-12T19:26:42.982Z        INFO    hub/server.go:288       listening for connections from Miners   {"address": "[::]:10002"}
    2017-10-12T19:26:42.984Z        INFO    hub/server.go:297       listening for gRPC API connections      {"address": "[::]:10001"}
    INFO [10-12|19:26:42] RLPx listener up                         self=enode://b1ac08dd98423379ed75a4ea28ea5f4d96896743a8648d7c20880f79378a13ef910e8e2d98c50c01fa2442d7ffd5811a3ce25650f8592aa3ee2ae10970f5b7a4@207.244.97.166:30343

Then in a separate session,

    $ sudo ./sonmminer 
    2017-10-12T19:27:09.595Z        DEBUG   miner/builder.go:75     building a miner        {"config": {"HubConfig":{"Endpoint":"127.0.0.1:10002","Resources":null},"FirewallConfig":null,"GPUConfig":null,"SSHConfig":null,"LoggingConfig":{"Level":-1}}}
    2017-10-12T19:27:09.603Z        DEBUG   miner/builder.go:83     discovering public IP address ...
    2017-10-12T19:27:09.611Z        INFO    miner/builder.go:109    discovered public IP address    {"addr": "207.244.97.166", "nat": "Not behind a NAT"}
    2017-10-12T19:27:09.611Z        INFO    miner/builder.go:140    collected Hardware info {"hardware": {"CPU":[{"cpu":0,"vendorId":"GenuineIntel","family":"6","model":"2","stepping":3,"physicalId":"0","coreId":"0","cores":1,"modelName":"QEMU Virtual CPU version 1.2.1","mhz":2400.082,"cacheSize":4096,"flags":["fpu","de","pse","tsc","msr","pae","mce","cx8","apic","sep","mtrr","pge","mca","cmov","pse36","clflush","mmx","fxsr","sse","sse2","syscall","nx","lm","rep_good","nopl","pni","vmx","cx16","popcnt","hypervisor","lahf_lm"],"microcode":"0x1"}],"Memory":{"total":1040777216,"available":554799104,"used":485978112,"usedPercent":46.69376928405013,"free":53800960,"active":423022592,"inactive":442867712,"wired":0,"buffers":51183616,"cached":404344832,"writeback":0,"dirty":8192,"writebacktmp":0,"shared":10915840,"slab":87986176,"pagetables":5287936,"swapcached":7966720},"GPU":[]}}
    2017-10-12T19:27:09.614Z        INFO    miner/overseer.go:207   subscribe to Docker events      {"since": "1507836429"}
    2017-10-12T19:27:09.622Z        DEBUG   miner/server.go:571     Using hub IP from config        {"IP": "127.0.0.1:10002"}
    2017-10-12T19:27:09.632Z        INFO    miner/server.go:156     handling Handshake request      {"req": ""}
    2017-10-12T19:27:09.639Z        INFO    miner/server.go:415     starting tasks status server
    2017-10-12T19:27:09.639Z        DEBUG   miner/server.go:368     handling tasks status request
    2017-10-12T19:27:09.639Z        INFO    miner/server.go:343     sending result  {"info": {}, "statuses": {}}
    2017-10-12T19:27:14.627Z        INFO    miner/server.go:512     yamux.Ping OK   {"rtt": "201.763µs"}

I assume that one hub supports a cluster of nearby hosts, similar to the master node on Kubernetes.

Finally, to run a docker container, create a yml file:

    $ cat > task.yml <<END
    > task:
    >   container:
    >     name: dtandersen/factorio:latest 
    >   resources:
    >       CPU: 1
    >       RAM: 10240kb
    >END

Now we need to figure out the miner on which to run the task:

    $ ./sonmcli --addr 127.0.0.1:10001 miner list
    Miner: 127.0.0.1:50928          Idle

    $ ./sonmcli --addr 127.0.0.1:10001 miner status 127.0.0.1:50928
    Miner: "127.0.0.1:50928" (003fe205-af29-4777-aa2c-a70fd50569ab):
    Hardware:
        CPU0: 1 x QEMU Virtual CPU version 1.2.1
        GPU: None
        RAM:
        Total: 992.6 MB
        Used:  463.5 MB
    No active tasks

Now we can deploy the task:

    $ ./sonmcli --addr 127.0.0.1:10001 task start 127.0.0.1:50320 task.yml
    Starting "dtandersen/factorio:latest" on miner 127.0.0.1:50928...
    ID 94b59103-0c43-4c1e-bc87-9e06abf39ad5
    Endpoint [27015/tcp->207.244.97.166:32772 34197/udp->207.244.97.166:32769]

This command returns when the task is deployed.

We inspect the miner again:

    $ ./sonmcli --addr 127.0.0.1:10001 miner status 127.0.0.1:50928
    Miner: "127.0.0.1:50928" (003fe205-af29-4777-aa2c-a70fd50569ab):
    Hardware:
        CPU0: 1 x QEMU Virtual CPU version 1.2.1
        GPU: None
        RAM:
        Total: 992.6 MB
        Used:  463.5 MB
    Tasks:
        1) 94b59103-0c43-4c1e-bc87-9e06abf39ad5

The entire process took less than 3 minutes in wall clock time.

Of course, a system this complex will have lots of edge cases. I hope the SONM team have solutions to these pressing issues with fog computing:

1. Security: user side and miner side

2. Proof of execution

3. Dishonest nodes

4. GPU tasks - SONM will support OpenCL but what about `nvidia-docker` required to run TensorFlow?

SONM marketplace release is scheduled this winter along with a wallet prototype. Here is a diagram of how it works:

![SONM marketpalce](https://camo.githubusercontent.com/0bb184c987ef6d88ddbd62fde21c596aa4795998/68747470733a2f2f7261772e6769746875622e636f6d2f736f6e6d2d696f2f646f63732f6d61737465722f617263682f73657175656e63652e7376673f73616e6974697a653d74727565)

I will test these products as they are released.

