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
SELECT x, y, z FROM xy NATURAL JOIN xz;
```
This query returns the maximal solution(all the matching cubes) by building up all the (x,y,z) when x matches using JOIN.

# Minimal solution:
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
This solution returns the minimal solution by "ZIP JOIN"ing two cyclic groups partitioned by y and z. First, they are matched pairwise 1-1, 2-2, 3-3 etc.. Then the extra ones are wrapped around to the first element in the other list. This is achieved by using index % count of the other list thanks to the nature of quotient groups. Note the row_number() window function is 1-indexed.
