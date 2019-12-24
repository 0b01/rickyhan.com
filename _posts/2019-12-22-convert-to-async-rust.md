---
layout: post
title:  "Weird Tricks to Detect Blocking in Async Rust"
date:   2019-12-22 00:00:00 -0400
# menu: main
categories: jekyll update
---

The Rust async story is extremely good and many people (like me) have already converted their networked applications to async.
In this post, I document some `async/await` pitfalls and show you how to avoid them. Finally, how to debug a async program.

# Blocking in async

The purpose of async runtime is to allow lightweight tasks to run *cooperatively* (as opposed to *preemptive* multitasking that OS schedulers use).
Tasks need to voluntarily yield control back to the scheduling thread 1) periodically, 2) when the task is unable to proceed, 3) idle.

In this model, long running or blocking calls cause starvation and defeat the entire purpose of async - the worst possible scenario that can happen.

### Long running computation

```rust
async fn foo(n: u64) {
    for i in 0..n {
        expensive(i);
    }
}
```

In this example, `async fn foo` calls a sync `fn expensive`. So when this code is compiled to a single state machine, the state transition only happens after the loop finishes.

To avoid starvation, control needs to be voluntarily *yielded* back to the runtime with the `task::yield_now` primitive ([1](https://docs.rs/tokio/0.2.6/tokio/task/fn.yield_now.html), [2](https://docs.rs/async-std/1.4.0/async_std/task/fn.yield_now.html)).


```rust
async fn foo(n: u64) {
    for i in 0..n {

        // yield every 10k iterations
        if i % 10_000 == 0 {
            task::yield_now().await;
        }

        expensive(i);
    }
}
```

### Blocking calls that you can't change

Long running or blocking sync functions written by others that you can't strategically insert yield_now.

```rust
async fn bar(img: &[u8]) {
    wave_function_collapse(&img);
    write_128_tb_to_floppy();
    block_until_september_ends();
}
```

There is a [`task::spawn_blocking`](https://docs.rs/tokio/0.2.6/tokio/task/fn.spawn_blocking.html) primitive which forces the runtime to spawn the sync task into a separate thread pool. Runtime gets notified when it finishes and joins. The thread gets recycled back into the threadpool.


```rust
task::spawn_blocking(|| {
    pause_indefinitely();
    expensive();
}).await;
```

## Resource leak from `Future`s that never complete

A long-running application could leak resources in the form of [unexpectedly long-lived allocations](https://blog.nelhage.com/post/three-kinds-of-leaks/). Assuming you are not doing anything obviously wrong, this is usually caused by some `Future` that never completes. And without you knowing, the runtime keeps holding onto the `Future` until the program gets killed by the kernel. This is usually in the realm of unknown unknown where "it sometimes breaks" functions cause all sorts of weird bugs that are impossible to avoid completely, but there are debugging techniques to find them in your async program.

As an example, here is a bug I encountered:

```rust
let mut stream = TcpStream::connect("127.0.0.1:8080").await?;
for i in 0..n {
    stream.write_all(b"hello world").await?;
}
```

This piece of code looks innocent enough, but the `write_all` here has a resource leak if the TCP write queue is full. This happens when the receiver is not `read(2)`ing from the receive buffer which will eventually get filled, and the kernel refuses to `ACK` incoming `SYN` packets so `SYN` backlog fills, the write queue gets filled, `write(2)` system call gets blocked, so the `Future` is never `Ready` when polled, creating a resource leak.

The fix is simple:

```rust
future::timeout(
    time::Duration::from_millis(0),
    stream.write_all(&buf)
).await;
```

By wrapping the Future with an immediate timeout, this future gets turned into a fire-and-forget and guarantees deallocation.

## General debugging tips

1. Avoid `futures::channel::mpsc::unbounded()`

Unbounded channel means that the consumer queue is unbounded so it can potentially cause unexpected memory leaks. So if you notice weird memory usage, you should immediately switch to the bounded channel `futures::channel::mpsc::channel(buffer: usize)` and set a small buffer size ~1. Chances are execution will halt and then you know somewhere in the consumer task is a future blocking the scheduler.

2. Avoid `std::sync`

First thing you should do in async conversion is changing the locks to use `futures_locks` or concurrency primitives in your runtime crate. Otherwise you will find strange blocks and panics.

3. Wrap some `Future` with `future::timeout`

The downside is that future based timeouts do not work when there's an infinite loops.

4. Put `dbg!(());` around every await to trace the missing line

This should be the last resort.

# Conclusion

Due to the nature of the Halting problem, it is the programmer's responsibility to ensure that the code in async context doesn't block. Accidentally blocking in async code is a mistake that's very easy and common to make and very hard to detect. In this post I presented several ways to reduce the surface area of accidentally making this mistake and also ways to debug accidentally blocking code.

## Further Reading

https://stjepang.github.io/2019/12/04/blocking-inside-async-code.html

https://www.reddit.com/r/rust/comments/ebpzqx/do_not_stop_worrying_about_blocking_in_async/

