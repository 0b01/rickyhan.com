---
layout: post
title:  "J Incunabulum Disected"
date:   2020-01-16 00:00:00 -0400
# menu: main
categories: jekyll update
---

The J Incunabulum is a toy interpreter written in a strange style of C. It interprets a subset of the array-based J language in the APL family. Similar languages include K, Q and Shakti. I was curious about what this interpreter does and wanted to learn more about J but couldn't find any explanation on this code online so I disected the source code and wrote some notes.

From [J Wiki](https://code.jsoftware.com/wiki/Essays/Incunabulum):

> One summer weekend in 1989, Arthur Whitney visited Ken Iverson at Kiln Farm and produced—on one page and in one afternoon—an interpreter fragment on the AT&T 3B1 computer. I studied this interpreter for about a week for its organization and programming style; and on Sunday, August 27, 1989, at about four o'clock in the afternoon, wrote the first line of code that became the implementation described in this document.

> Arthur's one-page interpreter fragment is as follows:

```c
typedef char C;typedef long I;
typedef struct a{I t,r,d[3],p[2];}*A;
#define P printf
#define R return
#define V1(f) A f(w)A w;
#define V2(f) A f(a,w)A a,w;
#define DO(n,x) {I i=0,_n=(n);for(;i<_n;++i){x;}}
I *ma(n){R(I*)malloc(n*4);}mv(d,s,n)I *d,*s;{DO(n,d[i]=s[i]);}
tr(r,d)I *d;{I z=1;DO(r,z=z*d[i]);R z;}
A ga(t,r,d)I *d;{A z=(A)ma(5+tr(r,d));z->t=t,z->r=r,mv(z->d,d,r);
 R z;}
V1(iota){I n=*w->p;A z=ga(0,1,&n);DO(n,z->p[i]=i);R z;}
V2(plus){I r=w->r,*d=w->d,n=tr(r,d);A z=ga(0,r,d);
 DO(n,z->p[i]=a->p[i]+w->p[i]);R z;}
V2(from){I r=w->r-1,*d=w->d+1,n=tr(r,d);
 A z=ga(w->t,r,d);mv(z->p,w->p+(n**a->p),n);R z;}
V1(box){A z=ga(1,0,0);*z->p=(I)w;R z;}
V2(cat){I an=tr(a->r,a->d),wn=tr(w->r,w->d),n=an+wn;
 A z=ga(w->t,1,&n);mv(z->p,a->p,an);mv(z->p+an,w->p,wn);R z;}
V2(find){}
V2(rsh){I r=a->r?*a->d:1,n=tr(r,a->p),wn=tr(w->r,w->d);
 A z=ga(w->t,r,a->p);mv(z->p,w->p,wn=n>wn?wn:n);
 if(n-=wn)mv(z->p+wn,z->p,n);R z;}
V1(sha){A z=ga(0,1,&w->r);mv(z->p,w->d,w->r);R z;}
V1(id){R w;}V1(size){A z=ga(0,0,0);*z->p=w->r?*w->d:1;R z;}
pi(i){P("%d ",i);}nl(){P("\n");}
pr(w)A w;{I r=w->r,*d=w->d,n=tr(r,d);DO(r,pi(d[i]));nl();
 if(w->t)DO(n,P("< ");pr(w->p[i]))else DO(n,pi(w->p[i]));nl();}

C vt[]="+{~<#,";
A(*vd[])()={0,plus,from,find,0,rsh,cat},
 (*vm[])()={0,id,size,iota,box,sha,0};
I st[26]; qp(a){R  a>='a'&&a<='z';}qv(a){R a<'a';}
A ex(e)I *e;{I a=*e;
 if(qp(a)){if(e[1]=='=')R st[a-'a']=ex(e+2);a= st[ a-'a'];}
 R qv(a)?(*vm[a])(ex(e+1)):e[1]?(*vd[e[1]])(a,ex(e+2)):(A)a;}
noun(c){A z;if(c<'0'||c>'9')R 0;z=ga(0,0,0);*z->p=c-'0';R z;}
verb(c){I i=0;for(;vt[i];)if(vt[i++]==c)R i;R 0;}
I *wd(s)C *s;{I a,n=strlen(s),*e=ma(n+1);C c;
 DO(n,e[i]=(a=noun(c=s[i]))?a:(a=verb(c))?a:c);e[n]=0;R e;}

main(){C s[99];while(gets(s))pr(ex(wd(s)));}
```

# The language

The J incunabulum interprets a subset of the J language.

## Restrictions:

1. Single char variable names
2. Single digit numbers
3. Limited operations

|       | `+`  | `{`  | `~`                   | `<` | `#` | `,` |
|-------|------|------|-----------------------|-----|-----|-----|
| monad | id   | size | iota                  | box | sha(pe) |     |
| dyad  | plus | from | find(unimplemented)   |     | rsh(ape) | cat |

## Examples:
```
    1

1
    +1

1
    1+1

2
    1,2,3
3
1 2 3
    {1,2,3        // size arr

3
    0{2,3,4       // arr[0]

2
    1{2,3,4       // arr[1]

3
    2{2,3,4       // arr[2]

4
    ~9            // iota
9
0 1 2 3 4 5 6 7 8
    a=~9          // assign iota(9) to a
9
0 1 2 3 4 5 6 7 8
    <1,2,3        // box 1,2,3 into atom

< 3
1 2 3

    <~9           // box ~9 into atom

< 9
0 1 2 3 4 5 6 7 8

    3#4           // 3 copies of 4
3
4 4 4
    4#3           // 4 copies of 3
4
3 3 3 3
    3#<~3         // 3 copies of boxed 0,1,2
3
< 3
0 1 2
< 3
0 1 2
< 3
0 1 2
    a=2,2         // define shape as a array
2
2 2
    b=a#3,4,5,6   // reshape
2 2
3 4 5 6
    #b            // shape of b is 2,2
2
2 2

```

# How to build

```
$ make
$ rlwrap ./ji # readline wrap utility
```

## Data types

```c
typedef char C;typedef unsigned long long I;
```

These type definitions make writing the rest of the interpreter more succinct. I ported this interpreter for 64-bit system as the original only works on 32.

```c
typedef struct a{I t,r,d[3],p[2];}*A;
```

The fields in this struct are:
    1. `t`: indicator for whether it's a boxed value
    2. `r`: rank as in length of tensor shape
    3. `d`: number of items along axis
    4. `p`: array to store values, its capacity is set by malloc

`A` defines the pointer type to `struct a` which is the data structure for nouns. For example, the program

```j
a=~3
3
0 1 2
```

allocates an `struct a` for `3`, runs `iota` the noun and stores the result to pronoun(variable) `a`.

> **Note:** This interpreter uses punning between `I` and `A` since the pointer size is equal to long long on a 64-bit system.

These are the functions related to shape calculation and memory manipulation for `struct a`:

`mv` is memmove.

```c
mv(d, s, n) I *d, *s; { DO(n, d[i] = s[i]); }
```

The `tr` function calculates the product over tensor shape. Not sure why it's named `tr`. It iterates from 0 to rank `r` and calculates the product of each d. For example, `tr` of a rank 0 number would return 1. `tr` of a rank 1 array of length n would return `1*n = n`, a rank 2 3 by 3 matrix would return `9` and so on.

```c
tr(r, d) I *d;
{
  I z = 1;
  DO(r, z = z * d[i]);
  R z;
}
```

`ga` calls `tr` and allocates a `struct a` and populates its fields with calling parameters `t, r, d`.

```c
A ga(t, r, d) I *d;
{
  A z = (A)ma(5 + tr(r, d)); // 5 is the size of struct without p[2]
  z->t = t, z->r = r, mv(z->d, d, r);
  R z;
}
```


`iota` declares a monadic verb `iota`, which takes a single number `n` and allocates a struct a that can store `1xn`, then assigns each value within a DO loop.

```c
V1(iota) {
  I n = *w->p;
  A z = ga(0, 1, &n);
  DO(n, z->p[i] = i);
  R z;
}
```

Similarly, `plus` takes 2 items of equal size and adds each pairwise entry.

```c
V2(plus) {
  I r = w->r, *d = w->d, n = tr(r, d);
  A z = ga(0, r, d);
  DO(n, z->p[i] = a->p[i] + w->p[i]);
  R z;
}
```


## The main loop

The main loop defines a REPL.

```c
I st[26]; // storage for pronouns [a-z]
main(){C s[99];while(gets(s))pr(ex(wd(s)));}
```


## wd

`wd` parses the input sentence and returns a null-terminated array of `I` for each character in the input.

```c
I *wd(s) C *s;
{
    I a, n = strlen(s), *e = ma(n + 1); C c;
    DO(n, e[i] = (a = noun(c = s[i])) ? a : (a = verb(c)) ? a : c);
    e[n] = 0;
    R e;
}
```

Each entry in the return array `e` is one of:
1. verb: index into the verb table (`C vt[]="+{~<#,";`)
2. noun: `A` pointer
3. neither: char

> **Note**: c89 mandates all variable to be declared at start of any block. As a counterexample, `{foo(); int a;}` is illegal.

The DO loop iterates over each character and populates the return array `e` based on whether it's a noun or verb or neither.

```c
DO(n, e[i] = (a = noun(c = s[i])) ? a : (a = verb(c)) ? a : c);
```

The `DO` loop is defined as a macro.

```c
#define DO(n,x) {I i=0,_n=(n);for(;i<_n;++i){x;}}
```

The `DO` macro is a ranged loop `i = 0..n`. `_n` is declared for hygiene and due to c89 restrictions.

> Always parenthesize parameter names within macros to avoid operator precedence bugs. For example,
>
> ```c
> #define CUBE(I) (I * I * I)
> int a = 81 / CUBE(2 + 1);
> int a = 81 / (2 + 1 * 2 + 1 * 2 + 1);  /* Evaluates to 11 */
> ```

Here are the implementations for `noun` and `verb`:

```c
...
I noun(c){A z;if(c<'0'||c>'9')R 0;z=ga(0,0,0);*z->p=c-'0';R z;}
I verb(c){I i=0;for(;vt[i];)if(vt[i++]==c)R i;R 0;}
```

`noun` callocates an `A` for the digit with `ga(0,0,0)` (more on `ga` later), converts the char from ASCII and sets the `p` field. The pointer is returned and stored in `e`.

`verb` looks up the index of the character in `vt` verb table: `C vt[]="+{~<#,";`. This index starts from 1 and is stored in `e`. For example, `~` would return 3.

If it's neither, then the character is stored directly. For example, `=`.

## ex

Before we delve into the code you should understand that many operators in J are overloaded based on arity.

```c
C vt[]="+{~<#,";
A(*vd[])()={0,plus,from,find,0,rsh,cat},
 (*vm[])()={0,id,size,iota,box,sha,0};
```

At index 1, the plus symbol can be interpreted as either `+3` the monadic `id` function or `1+3` the dyadic `plus` function.

The code for `ex` is:

```c
A ex(e) I *e;
{
    I a = *e;                           // fetch first item
    if (qp(a)) {                        // is it pronoun(variable)?
        if (e[1] == '=')                // is it being assigned to
            R st[a - 'a'] = ex(e + 2);  // ex(rhs) and cache
        a = st[a - 'a'];                // fetch from storage
    }
    R qv(a) ?                           // is it verb(function)?
        (*vm[a])(ex(e + 1))             // run monad on ex(rest)
        :
        e[1] ?                          // is the next char defined
            (*vd[e[1]])(a, ex(e + 2))   // run the next char as dyad
            :
            (A)a                        // must be noun(digit)
    ;
}
```

This recursive function evaluates from right to left which is the order of execution for all APL family languages.

The idea is that verbs operate on `struct A` which can be a pronoun or a noun.

# pr

To understand this print function, you will have to understand the data structure of `struct a`.

```c
pr(w) A w;
{
  I r = w->r, *d = w->d, n = tr(r, d);
  DO(r, pi(d[i]));              // iterate over rank to print length of each dimension, aka print shape
  nl();
  if (w->t)
    DO(n, P("< "); pr(w->p[i])) // if it's a list of boxed values, print each constituent boxed value
  else
    DO(n, pi(w->p[i]));         // print each integer
  nl();
}
```

Since the [`find` verb](https://code.jsoftware.com/wiki/Vocabulary/ecapdot) is not implemented, here is the [implementation](https://github.com/jsoftware/jsource/blob/01da2f88a44d65fc65a96b4eebe342cf88361ac8/jsrc/v1.c#L191) for J.