---
layout: post
title:  "Pixel Art Algorithm: Drawing Smooth Bezier Curves"
date:   2019-01-12 00:37:02 -0400
# menu: main
categories: jekyll update
---

This post is a demo of the vector tool in my pixel art editor tool Xprite.

<div style="background: azure;">
<style>
    #canvas {
        cursor: none;
        height: 600px;
        width: 600px;
        border: 1px solid blue;
    }
</style>
<canvas id="canvas" width="600" height="600"> </canvas>
<script src="/static/bezier/xprite-web.js"></script>
</div>

Press `b` for pencil. Press`v` for vector. `F5` to clear canvas.

## The algorithm

1. Store cursor positions as a polyline(a vector of coordinates).

2. Simplify polyline. Connect two points with a line and check if the distance between next point and line exceeds some predefined threshold.

3. Interpolate. Convert the simplified polyline into a vector of cubic bezier curves. I used an implementation from d3.

4. Segment each bezier curve to monotonic subcurves. The pixel sorting algorithm(from previous post) only works with monotonically increasing or decreasing curves whose first and second derivatives don't change sign. This is done by solving quadratic and cubic bezier equation for `t` to find extrema.

5. Rasterize by sampling. I use [indexset](https://docs.rs/indexmap/1.0.2/indexmap/) to store continuous lines. Dedupe takes O(1) time.

6. Optimize pixel selection cost. Each pixel in the rasterized line is scored by distance from center to the smooth curve. The goal is to minimize total cost. However, this step is not used since this problem in NP and I'm not sure how to speed up(or if it's even possible).

7. [Pixel perfect](http://rickyhan.com/jekyll/update/2018/11/22/pixel-art-algorithm-pixel-perfect.html). As an alternative to step 6, removing intermediate pixels actually works pretty well.

8. Finally. Sort monotonic segments by slope. See my previous post on this.

## Current Roadmap:

### Milestones

1. Finding the right abstractions
* [x] Canvas
* [x] Renderer
* [x] Layer

1. Core functionalities
* [x] Hotkeys
* [x] Save
* [x] Load
* [x] Python Scripting
* [x] JavaScript Scripting
* [x] Palette

1. Basic tools (Release target)
* [x] Pencil
* [x] Line
* [x] Color Picker
* [x] Paint Bucket
* [x] Eraser
* [x] Shapes - Rect
* [x] Shapes - Circle
* [ ] Vector tools
* [ ] Select/Marquee
* [ ] Pattern Brush
* [x] Texture Synthesis(wave function collapse)

1. Layers
* [ ] Layer groups

1. Animation
* [ ] Celluloid
* [ ] Preview window

2. Web UI

1. Collaborative edit