---
layout: post
title:  "Why We Need Type-Checked Neural Network"
date:   2018-02-16 00:00:00 -0400
categories: jekyll update
---

Imagine a framework-agnostic DSL with strong typing, dimension and ownership checking and lots of syntax sugar. What would it be like? As interesting as it is, here is why there needs to a langauge for neural network:

1. Multi-target. Write once, run everywhere(interpreted or compiled).

2. Typechecking with good type annotation.

3. Parallellize with language-level directives

4. Composition(constructing larger systems with building blocks) is easier

5. Ownership system because GC in CUDA is a nightmare

6. No more frustration from deciphering undocumented code written by researchers. The issue is, an overwhelming majority of researchers are not programmers, who care about the aesthetics of clean code and helpful documentation. I get it - people are lazy and unsafe unless the compiler forces them to annotate their code.

I have thought a lot about this. Here is an example snippet of the language I have in mind:

```rust
use conv::{Conv2d, Dropout2d, maxpool2d};
use loss::log_softmax;
use nonlin::relu;
use lin::Linear;

node Mnist<?,c,h,w -> ?,10>;

weights Mnist {
    conv1: Conv2d<?,c,hi,wi -> ?,c,ho,wo>::new(in_ch=1, out_ch=10, kernel_size=5),
    conv2: Conv2d<?,c,hi,wi -> ?,c,ho,wo>::new(in_ch=10, out_ch=20, kernel_size=5),
    dropout: Dropout2d<?,c,h,w -> ?,c,h,w>::new(p=0.5),
    fc1: Linear<?,320 -> ?,50>::new(),
    fc2: Linear<?,50 -> ?,10>::new(),
}

graph Mnist {
    fn new() {
        fc1.init_normal(std=1.);
        fc2.init_normal(std=1.);
    }

    fn forward(self, x) {
        x
        |> conv1            |> maxpool2d(kernel_size=2)
        |> conv2 |> dropout |> maxpool2d(kernel_size=2)
        |> view(?, 320)
        |> fc1 |> relu
        |> self.fc2()
        |> log_softmax(dim=1)
    }

    fn fc2(self, x: <?,50>) -> <?,10>{
        x |> fc2 |> relu
    }
}
```

As you can see, this is inspired by Rust, PyTorch, Elixir.

Here are some random syntactical ideas:

1. Stateful symbols are capitalized

2. Impure functions must be annonated

3. Local variables cannot be shadowed

4. Function args have keyword

5. Be explicit where you can

6. Pipe operator input is first argument of function

However, this will be an extraordinary undertaking *IF* I decide to implement it.
