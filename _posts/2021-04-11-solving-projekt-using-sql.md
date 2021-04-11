---
layout: post
title:  "Solving PROJEKT Using SQL"
date:   2021-04-11 00:00:00 -0400
categories: jekyll update
---

Today I came across [this blog post](https://github.com/frankmcsherry/blog/blob/master/posts/2018-12-30.md) on solving a 3D projection puzzle called PROJEKT.

<iframe width="560" height="315" src="https://www.youtube.com/embed/kWmbdk0pT1s" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

I bought the game but the puzzles are way too simple. I got bored about ~20 puzzles in so I decided to reimplement the algorithm in SQL instead:

Maximal version:

```sql
WITH xy(x, y) AS (
    VALUES
    (0, 0),
    (0, 1),
    (0, 3),
    (0, 4),
    (1, 1),
    (1, 3),
    (2, 1),
    (2, 2),
    (3, 2),
    (3, 3),
    (3, 4),
    (4, 0),
    (4, 1),
    (4, 2)
),
xz(x, z) AS (
    VALUES
    (0, 2),
    (0, 3),
    (0, 4),
    (1, 2),
    (1, 4),
    (2, 1),
    (2, 2),
    (2, 3),
    (3, 0),
    (3, 1),
    (3, 3),
    (3, 4),
    (4, 1),
    (4, 4)
)
SELECT x, y, z FROM xy JOIN xz USING(x);
```

Minimal solution:
```sql
SELECT x, y, z FROM (
    SELECT x, y, z,
    COUNT() OVER (PARTITION BY x,z) AS ny,
    COUNT() OVER (PARTITION BY x,y) AS nz,
    ROW_NUMBER() OVER (PARTITION BY x,z) AS iy,
    ROW_NUMBER() OVER (PARTITION BY x,y) AS iz
    FROM xy JOIN xz USING(x)
)
WHERE (iz-1) % ny == (iy-1) % nz; -- ROW_NUMBER() is 1-indexed
```
