---
layout: post
title:  Hacking Google reCaptcha
date:   2017-11-10 00:00:00 -0400
categories: jekyll update
---

Bypassing Google reCaptcha is possible if not simple. This post is a detailed breakdown of how it works.

# Background

A page is protected by reCaptcha means that form must be accompanied by `g-recaptcha-response` which is then verified on the backend. Based on the probability calculated by a machine learning algorithm, reCaptcha gives you a range of captchas: from none to very difficult. Instead of having to solve the captcha by hand, this method allows using another browser session cookie which Google deems "human" to bypass a captcha. These "valid" browser sessions can be farmed en masse(I will not cover).

# Overview

I used a simple nodejs server that serves a form to collect Google reCaptcha response. The caveat is: the browser must have the same hostname as the real website which is achieved by changing the `/etc/hosts` file or hosting a DNS server.

![harvestor](https://i.imgur.com/0QqEQDI.png)

```javascript
app.post('/submit', function(req, res) {
  log('info', `Successful Token: ${req.body['g-recaptcha-response']}`);
  const token = req.body['g-recaptcha-response'];
  const timestamp = new Date();
  saveToken(token, timestamp);
  return res.redirect(`${config.remotehost}:${app.get('port')}/harvest`);
});
```

On the other hand, I am using a browser automation tool to submit a form which is protected by recaptcha. We need `g-recaptcha-response` in a hidden field. So when the page is loaded, we `await` for a valid token:

```js
await validToken(pageLoadedTime)
```

And this then sends a message to all connected harvestors via websocket:

```js
function validToken(pageLoadedTime) {
    wss.broadcast('needtoken');
    return new Promise((resolve, reject) => {
        (function wait() {
            for (let token of tokens)
                if (token.timestamp.getTime() > pageLoadedTime)
                    resolve(token.token);
            setTimeout( wait, 200 );
        })();
    });
}
```

We use [invisible recaptcha](https://developers.google.com/recaptcha/docs/invisible) on the harvestor page, because its actions can be programmatically triggered.

```html
<div class="g-recaptcha" data-sitekey="<%= sitekey %>" data-callback="sub" data-size="invisible"></div>
<script>
  function sub(){
    document.getElementById("submit").click();
  }
  var wss = new WebSocket("ws://www.hostname.com:8080", "protocolOne");
  wss.onmessage = function (event) {
    if("needtoken" === event.data) {
      grecaptcha.execute();
    } else {
      console.log("CONNECTED");
    }
  }
</script>
```

Now, there is a way to farm these valid harvestor sessions such that the first 20 or so recaptcha verifications are bypassed. Now the automated browser window has a valid reCaptcha, it needs to fill the hidden field and call the callback function! Great work Google!

```js
return nightmare
.evaluate((key) => {
    document.getElementById("g-recaptcha-response").innerHTML = key;
    checkoutAfterCaptcha(); // uncomment to work!
}, await validToken(pageLoadedTime))
.wait(2000)
.screenshot('ok.png')
.end();
```