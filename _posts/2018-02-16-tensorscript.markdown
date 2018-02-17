---
layout: post
title:  "The need for a TensorScript"
date:   2018-02-16 00:00:00 -0400
categories: jekyll update
---

I have been thinking about a framework-agnostic DSL that transpiles to Tensorflow and/or PyTorch with strong typing, dimension and ownership checking and lots of syntax sugar. This is borne out of frustration: I am so tired of deciphering undocumented code written by researchers. The issue is, an overwhelming majority of researchers are not programmers, who care about the aesthetics of clean code and helpful documentation. I get it - people are lazy and unsafe unless the compiler forces them to annotate their code.

Here is an example of TensorScript(which is vaporware for now):

```rust
use conv::{Conv2d, Dropout2d, maxpool2d};
use loss::log_softmax;
use nonlin::relu;
use lin::Linear;

declare Mnist<?,c,h,w -> ?,10>;

weights Mnist {
    conv1: Conv2d<?,c,hi,wi -> ?,c,ho,wo>::new(in_ch=1, out_ch=10, kernel_size=5),
    conv2: Conv2d<?,c,hi,wi -> ?,c,ho,wo>::new(in_ch=10, out_ch=20, kernel_size=5),
    dropout: Dropout2d<?,c,h,w -> ?,c,h,w>::new(p=0.5),
    fc1: Linear<?,320 -> ?,50>::new(),
    fc2: Linear<?,50 -> ?,10>::new(),
}

ops Mnist {
    op new() {
        conv1.init_normal();
        conv2.init_normal();
    }

    op forward(x) {
        x
        |> conv1            |> maxpool2d(kernel_size=2)
        |> conv2 |> dropout |> maxpool2d(kernel_size=2)
        |> view(?, 320)
        |> fc1 |> relu
        |> self.fc2
        |> log_softmax(dim=1)
    }

    // impure functions need annotation
    op fc2(self, x: <?,50>) -> <?,10>{
        x |> fc2 |> relu
    }
}
```

However, this will be an undertaking *if* I decide to do it.
