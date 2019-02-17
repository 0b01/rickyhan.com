---
layout: post
title:  "Kingston Crabfighting: Assembly Puzzler"
date:   2019-01-12 00:37:02 -0400
# menu: main
categories: jekyll update
---

Help your crab beat up all the other crabs at the beach by programming assembly. Don't forget you only move sideways. Read the manual below to proceed.

## <a href="/static/crabs/index.html" target="_blank">Play Now</a>

*I made this game for a local 6 hour game jam. It is unpolished but very fun to play!*

Theme music:

<iframe width="100" height="100" src="https://www.youtube-nocookie.com/embed/gzVb5nYlKzk" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

## Crab VM

There are 5 registers `AMVHR`:

* `A`:  Deneral purpose accumulator. Default argument for some op codes as documented below.

* `M`: Motor control. Your crab can only crawl sideways. M controls its movement. If it's positive, then it moves to the right and vice versa. Note: movement is only actuated for every cycle after M register has been set positive.

```
MOV 1 M     ; no movement
NOP         ; moves 1 to the right
NOP         ; moves 1 to the right
MOV 0 M     ; moves 1 to the right
NOP         ; stands still
MOV -10 M   ; stands still
NOP         ; moves 1 to the left
```

* `V`, `H`:  General purpose accumulator. Originally intended for object detection which was too complicated.

* `R`: Rotation mod 4. Note: 0 is down, increments clockwise.

## Instructions

* `LABEL:`: Labels must be on their own line (cannot be followed by other instructions unlike zachtronics games).

```
MOV 10 A
L:
SUB 1 A
JGZ L
```

* `MOV`

```
MOV 1 A
MOV R A
```

* `ADD`, `SUB`

```
ADD 1 A
ADD A A
SUB 1 M
```

* `NEG reg`: Negates value in register.

```
NEG M
```

* `NOP` No operation. Also known as noop

* `JMP label`: Point the instruction pointer to specified label.

* `JEZ`: Jump if A == 0

* `JNZ`: Jump if A != 0

* `JGZ`: Jump if A > 0

* `JLZ`: Jump if A < 0

* `JRO`: Unconditional relative jump with immediate value or value from register.

```
JRO -1      ; jump to previous instruction
JRO 1       ; jump to following instruction
JRO A       ; relative to jump the instruction stored in A
```

* `RCW`: Rotate clockwise

* `RCC`: Rotate counterclockwise


## Example program:

The first level can be solved using this code:

```
MOV -1 M
L:
JMP L
```

## User interface

Use `C-return` to step through your code.

Press `Esc` or `C-c` to stop debugger.

## Future improvements

The game is surprisingly fun and in the future I would like to add mechanics such as boss fights, object detection, fork/join (similar to REPL in Exapunks).

[Source code](https://github.com/rickyhan/crabs)
