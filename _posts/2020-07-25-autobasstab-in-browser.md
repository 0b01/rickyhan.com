---
layout: post
title:  "AutoBassTab in Browser"
date:   2020-07-25 00:00:00 -0400
categories: jekyll update
---

# [AutoBassTab Web](http://bass.pickitup247.com)

Many people emailed me about AutoBassTab with song requests so I decided to make a website where people can upload songs and then get transcription.

Here's what I did:

1. Convert tensorflow model to tfjs.
2. Compile postprocessing binaries(in Rust and C++) to wasm modules.
3. Set up frontend based on spleeter-web.
4. All the expensive operations are run in WebWorker.

Note the website version does not make use of spleeter for two reasons:

1. Spleeter uses stft operations that tfjs doesn't support
2. Accuracy is similar to simply applying a lowpass filter
