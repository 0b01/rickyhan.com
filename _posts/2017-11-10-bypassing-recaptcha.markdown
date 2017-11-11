---
layout: post
title:  Hacking Google reCaptcha
date:   2017-11-10 00:00:00 -0400
categories: jekyll update
---

This post is a detailed breakdown of how to bypass Google reCaptcha.

# Background

"Protected by reCaptcha" means that a form has to be accompanied by a `g-recaptcha-response` field, which is then verified by the backend through a request to reCaptcha server. Based on the probability calculated by a machine learning algorithm, reCaptcha may give you captchas with difficulty nonexistent, very hard and everything in between. Instead of having to solve the captcha by hand, this method allows using another valid browser session cookie which Google deems "human" to effectively bypass a captcha. These "valid" browser sessions can be farmed en masse. According to [this report](https://www.blackhat.com/docs/asia-16/materials/asia-16-Sivakorn-Im-Not-a-Human-Breaking-the-Google-reCAPTCHA-wp.pdf), "[...] a checkbox captcha is obtained after the beginning of the 9th day from the cookie’s creation, without requiring any browsing activities and type of network connection [...]. Our experiment also revealed that each cookie can receive up to 8 checkbox captchas in a day."

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
    checkoutAfterCaptcha();
}, await validToken(pageLoadedTime))
.wait(2000)
.screenshot('ok.png')
.end();
```