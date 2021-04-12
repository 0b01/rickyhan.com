---
layout: post
title:  "Solving .projekt Using SQL"
date:   2021-04-11 00:00:00 -0400
categories: jekyll update
---

Today I came across [this blog post](https://github.com/frankmcsherry/blog/blob/master/posts/2018-12-30.md) on solving a 3D projection puzzle called .projekt.

<iframe width="560" height="315" src="https://www.youtube.com/embed/kWmbdk0pT1s" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

I bought the game but the puzzles are way too simple. I got bored about ~20 puzzles in so I decided to reimplement the algorithm in SQL instead:

# Maximal Solution

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
SELECT x, y, z FROM xy NATURAL JOIN xz;
```
This query returns the maximal solution(all the possible set of cubes) by building up all the (x,y,z) when x matches using JOIN.

# Minimal Solution
```sql
SELECT x, y, z FROM (
    SELECT x, y, z,
    COUNT() OVER (PARTITION BY x,z) AS nz,
    COUNT() OVER (PARTITION BY x,y) AS ny,
    ROW_NUMBER() OVER (PARTITION BY x,z) AS iz,
    ROW_NUMBER() OVER (PARTITION BY x,y) AS iy
    FROM xy JOIN xz USING(x)
)
WHERE (iy-1) % nz == (iz-1) % ny; -- ROW_NUMBER() is 1-indexed
```
This query returns the minimal solution by "ZIP JOIN"ing two cyclic groups partitioned by y and z. First, they are matched pairwise 1-1, 2-2, 3-3 etc.. Then the extra ones from the longer list are wrapped around to the first elements in the shorter list. This can be achieved by index mod length thanks to quotient groups. Note the row_number() window function is 1-indexed so I have to subtract 1.

Also to answer the combinatorics question posed in the original blog post the total number of minimal solutions is `\sum_{x=0}^{n} max(y_x, z_x)` where y_x is the number of y goal blocks in x.
