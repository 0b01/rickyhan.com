---
layout: post
title:  "Pixel Art Algorithm: Pixel Perfect"
date:   2018-11-22 00:37:02 -0400
# menu: main
categories: jekyll update
---

**Pixel Perfect** is the canonical name of a simple algorithm that removes the middle pixel in an L-shape. This converts any pencil line into 1-pixel wide from start to finish.

![pixel perfect](/static/pixelart/pixelperfect.svg)

![](https://i.imgur.com/H9sqW5P.png)

Every decent pixel art program has it: Graphics Gale, Aseprite, Hexels. It is a simple loop that checks every pixel and filters it out if it's part of an L-shape.

```rust
pub fn pixel_perfect(path: &[Pixel]) -> Vec<Pixel> {
    if path.len() == 1 || path.len() == 0 {
        return path.iter().cloned().collect();
    }
    let mut ret = Vec::new();
    let mut c = 0;

    while c < path.len() {
      if c > 0 && c+1 < path.len()
        && (path[c-1].point.x == path[c].point.x || path[c-1].point.y == path[c].point.y)
        && (path[c+1].point.x == path[c].point.x || path[c+1].point.y == path[c].point.y)
        && path[c-1].point.x != path[c+1].point.x
        && path[c-1].point.y != path[c+1].point.y
      {
        c += 1;
      }

      ret.push(path[c]);

      c += 1;
    }

    ret
}
```