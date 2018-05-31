---
layout: post
title:  "Future Trends in Systems Programming"
date:   2018-05-30 00:00:00 -0400
categories: jekyll update
---

# WebAssembly Kernel / Subsystem

WebAssembly kernel or subsystem is a good idea for reasons best explained in [this talk](https://www.destroyallsoftware.com/talks/the-birth-and-death-of-javascript). It is from 2014 but more exigent than ever - wasm microkernels are already gaining traction.

JavaScript is a bad language and people had to use it - resulting in tremendous ingenuities in tooling: one such tool is compiling other languages to asm.js(the precursor to WebAssembly) and, one thing led to another, WebAssembly was standardized. The wasm microkernel(putting some userland stuff back into kernel) is a great idea for several reasons:

1. (Eventually) faster than native speed due to elimination of syscalls overhead, which requires userland/kernel(ring 3/0) address space/virtual memory context switching.

3. Huge portability gain by compiling to wasm isa + HTML DOM instead of supporting a myriad of CPU architectures and GUIs frameworks. This is what JVM could have been but never was.

4. WebAssembly is designed to run safely on remote computers, so such a kernel can be sandboxed without losing performance. As a matter of fact, since everything runs in ring 0, cache flush from monkey patching Spectre/Meltdown is unnecessary, and your local data center will generate significantly less heat.

Twenty-five years ago, Linus was a young programmer with big ideas and a small repo of a few thousand lines of a prototype kernel. After 25 years of hardware progress, Linux has gained bloat: a recent release [removed more lines than added](https://lkml.org/lkml/2018/4/15/201). Along with increasing demand for thin OS layer in virtualization such as Docker, the so-called "modern" OS needs to be revamped. As a matter of fact, the current preferred abstraction is "one user, multi-computer".

In conclusion, thanks to a bunch of expedient choices, wasm subsystem clearly is the future of programming and the future is pretty good. If you still aren't convinced or want to find out more, check out [nebulet blog](http://lsneff.me/nebulet-booting-up/) and [cervus project page](https://github.com/cervus-v/cervus). Definitely number one on my list.

# Persistent Memory or Non-Volatile Memory (PMEM/NVM)

For many years computer applications organized their data between two tiers: memory and storage. The emerging persistent memory technologies introduce a third tier. Persistent memory (or pmem for short) is accessed like volatile memory, using processor load and store instructions, but it retains its contents across power loss. ([src](http://pmem.io))

This is going to change things for many reasons. A new programming model bypasses OS I/O and directly R/W data to memory from the application (via pages/blocks, although Intel Optane is byte-addressable) - resulting in significantly higher transaction rates. It brings into reality systems yet to be explored: zero-cost sleep mode with persistent cache, new paging mechanisms in modern OS's, [more performant filesystem](https://www.cs.utexas.edu/~simon/sosp17-final207.pdf) and everything about computer architecture and programming models in general: skipping the part where you pull data into memory, or flush memory back into hdd/ssd/nvram. The most significant implications are in cloud computing and in-memory databases(such as LMDB-backed databases).

# Smart Contract Compiler Toolchain

Despite intrinsic scaling issues and over-the-top hype, it is obvious blockchain as an execution layer is here to stay. As of 2018, smart contract in its early days is the wild west of programming: bug bounty, formal verification, PL design, etc. Ethereum is basically a billion dollar bounty program. Blockchains like ETH, ETC, ADA, EOS, NEO all have different VMs, APIs, preferred methods of verification, etc..

Smart contract implies "code is law" but it is difficult to audit 1000 lines of subtle code, hence the necessity of a compiler toolchain that simplifies development with multiple VM opcode targets, standard libraries across blockchains, custom DSLs that compiles to IR...

Some cool projects include:

* Cardano IELE uses a variant of LLVM and is compatible with EVM bytecode. Formally verifiable thanks to C-style semantics.

* [Langauge oriented programming](http://www.michaelburge.us/2018/05/15/ethereum-chess-engine.html). The idea is DSLs consistently apply security rules, and reduce the amount of code to be reviewed.

* EOS uses C API and WebAssembly which is a universal compile target that enables applications to be developed in any language.

Blockchain is a potentially rewarding domain to get into for systems programmers.

# ML(Machine Learning, not the language) in systems

ML will penetrate every layer of the software stack according [this talk](http://learningsys.org/nips17/assets/slides/dean-nips17.pdf). Basically, computer systems are filled with "approximate solutions" that are better suited for ML. These include compilers, networking, OS, etc. that have to work well "in general case" and don’t adapt to actual usage patterns.

* Compilers: instruction scheduling, register allocation, loop nest parallelization strategies, …

* Networking: TCP window size decisions, backoff for retransmits, data compression, ...

* Operating systems: process scheduling, buffer cache insertion/replacement, file system prefetching, …

* Job scheduling systems: which tasks/VMs to co-locate on same machine, which tasks to pre-empt, ...

* ASIC design: physical circuit layout, test case selection, …

Also from the slides, even the most fundamental of data structure, the B-Tree can be optimized with ML. Replacing B-tree indices, hash maps, and Bloom filters with data-driven indices learned by deep learning models. In experiments, the learned indices outperform the usual stalwarts by a large margin in both computing cost and performance, and are auto-tuning.

* [pelotondb](https://github.com/cmu-db/peloton) is one such DB that tunes itself autonomously by predicting future workload.

In the future, ML will be integrated not only at server/workstation scale but also traditional software, as a growing number of computers are now shipping with [specialized deep learning coprocessors](https://basicmi.github.io/Deep-Learning-Processor-List/).

# Obligatory [Rust](https://www.rust-lang.org) Plug

* zero-cost abstractions

* move semantics

* guaranteed memory safety

* threads without data races

* trait-based generics

* pattern matching

* type inference

* minimal runtime

* efficient C bindings

# Conclusion

In this short but information-dense blog post, I surveyed some interesting trends in systems programming that could be potentially huge in near future.
