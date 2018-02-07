---
layout: post
title:  "Fun weekend hack: cool effects pedals"
date:   2018-02-06 00:00:00 -0400
categories: jekyll update
---

A guitar effect alters how the input sounds by adding distortion, delaying signal, shifting pitch/frequency and changing dynamics and loudness. Most physical pedals are analog - altering the electric signals directly, with non-existent latency. Digital effect units sample the source input at high frequencies(44100 Hertz) and quickly process using DSP algorithms so the output appears live.

This projects uses JACK(**J**ACK **A**udio **C**onnection **K**it) and uses the abstraction of jack. The program registers input and output ports on JACK server and processes audio as it comes in. I googled around and found [rust-jack](https://github.com/RustAudio/rust-jack) and quickly got audio playback to work.

# Setup

I first booted up a server with `qjackctl` and changed setup to lower latency(bottom right corner)...

![qjackctl](https://i.imgur.com/7052cHF.png)

Then got a playback example to work...

```rust
extern crate jack;
use std::io;

fn main() {
    let (client, _status) =
        jack::Client::new("rasta", jack::ClientOptions::NO_START_SERVER).unwrap();

    // register ports
    let in_b = client
        .register_port("guitar_in", jack::AudioIn::default())
        .unwrap();
    let mut out_a = client
        .register_port("rasta_out_l", jack::AudioOut::default())
        .unwrap();
    let mut out_b = client
        .register_port("rasta_out_r", jack::AudioOut::default())
        .unwrap();

    let process_callback = move |_: &jack::Client, ps: &jack::ProcessScope| -> jack::Control {
        let out_a_p = out_a.as_mut_slice(ps);
        let out_b_p = out_b.as_mut_slice(ps);
        let in_b_p = in_b.as_slice(ps);
        out_a_p.clone_from_slice(&in_b_p);
        out_b_p.clone_from_slice(&in_b_p);
        jack::Control::Continue
    };
    let process = jack::ClosureProcessHandler::new(process_callback);
    let active_client = client.activate_async((), process).unwrap();

    // Wait for user input to quit
    println!("Press enter/return to quit...");
    let mut user_input = String::new();
    io::stdin().read_line(&mut user_input).ok();

    active_client.deactivate().unwrap();
}
```

This program copies a `&[f32]` of length `samples/period`(in this case 128) from input port to output port 44100 times per second.

Now it is time to implement some cool effects! But first, I need some kind of trait to keep things organized.

# `Effect` trait

```rust
use std::slice;
pub mod overdrive;
pub trait Effect : Send {
    fn new() -> Self
        where Self: Sized;
    fn name(&self) -> &'static str;
    fn process_samples(&self, input: &[f32], output_l: &mut [f32], output_r: &mut [f32]) {
        output_l.clone_from_slice(input);
        output_r.clone_from_slice(input);
    }
    fn bypass(&mut self);
    fn ctrl(&mut self, msg: CtrlMsg);
}
```

This trait defines the minimum set of methods for an effect struct. Note that Effect needs to be `Send` for it to cross thread boundaries(for example, move into the closure) and `Sized` for it to be a [trait object](https://doc.rust-lang.org/book/first-edition/trait-objects.html#object-safety).

# Overdrive

Then I wrote a very simple but real effect: overdrive. Guitarists originally obtained an overdriven sound by turning up their vacuum tube-powered guitar amplifiers to high volumes, which caused the signal to get distorted(wiki).

```rust
use effects::{Effect, CtrlMsg};
pub struct Overdrive {
    pub bypassing: bool,
}

/// Audio at a low input level is driven by higher input
/// levels in a non-linear curve characteristic
/// 
/// For overdrive, Symmetrical soft clipping of input values has to
/// be performed.
impl Effect for Overdrive {
    fn new() -> Self {
        Overdrive {
            bypassing: false
        }
    }
    fn name(&self) -> &'static str {
        "overdrive"
    }
    fn process_samples(&self, input: &[f32], output_l: &mut [f32], output_r: &mut [f32]) {
        if self.bypassing {
            output_l.clone_from_slice(input);
            output_r.clone_from_slice(input);
        }
        let slice = input.iter().map(|&x| {
            let x = x.abs();
            if 0. < x  && x < 0.333 {
                2. * x
            } else if 0.333 < x && x < 0.666 {
                let t = 2. - 3. * x;
                (3. - t * t) / 3.
            } else {
                x
            }
        }).collect::<Vec<f32>>();
        output_l.clone_from_slice(&slice);
        output_r.clone_from_slice(&slice);
    }
    fn bypass(&mut self) {
        self.bypassing = !self.bypassing;
    }
    fn ctrl(&mut self, msg: CtrlMsg) {
        use self::CtrlMsg::*;
        match msg {
            Bypass => self.bypass(),
        }
    }
}
```

This effect doubles quiet signals such as eddy currents produced by pickup. It uses a [symmetrical soft clipping](http://sound.whsites.net/articles/soft-clip.htm) to amplify the middle parts. It sounds exactly like the overdrive on my amp. Not really a fan but I was glad it works.

# Delay 

After writing overdrive, I wanted to implement a time-dependent effect. Some sort of delay, echo, reverb would be nice. A delay of 0.2 second with 0.3 feedback means an attenuated echo of amplitude 0.3 of the original after 0.2 seconds, and then another echo of amplitude of 0.09 after 0.4 seconds.

This can be done in 2 ways:

1. Convolve the original signal with an impulse response. See this excellent [talk](https://youtu.be/HTfa2UF_oiI?t=27m53s). However, this is out of scope for our purpose.
2. Use a longer buffer to store previous signals and calcuate an attenuated signal from t samples before. A good data structure to use for this is the **ring buffer**.

This is the implementation for this effect(explanation below):

```rust
for bufidx in 0..self.frame_size as usize {
    if self.writer_idx >= self.delay_buffer_size {
        self.writer_idx = 0;
    }
    self.reader_idx = if self.writer_idx >= self.delay_time {
        self.writer_idx - self.delay_time
    } else {
        self.delay_buffer_size as usize + self.writer_idx - self.delay_time
    };
    let processed = input[bufidx] + (self.delay_buffer[self.reader_idx] * self.feedback);
    self.delay_buffer[self.writer_idx] = processed;
    let out = (processed + 0.5).cos();
    output_r[bufidx] = out;
    output_l[bufidx] = out;
    self.writer_idx += 1;
}
```

This effect uses a ring buffer which is a fixed sized vector for streaming data. It overwrites data in the front when a pointer reaches the end. A notable property of the ring buffer is that it's locklessly thread safe as long as there is only one reader and one writer whose roles aren't switched, and writer pointer never catches up with reader pointer. The difference between writer and reader pointers is always the delayed samples. The rest is trivial.

# Auto Wah

Auto Wah is my personal favorite(vocoder after). The idea is simple: autowah ≡ filter controlled by envelope follower. The louder the sound, the more oo, and conversely aa. The filter can be tweaked to output different human sounding vowel voices like ooii(highpass filter), ooaa(bandpass), ooee(lowpass). Unlike a conventional wah pedal, it only responds to the volume of the input signal - buffer not needed. The code below is ported from a C++ implementation found on [github](https://github.com/dangpzanco/autowah). All credit goes to the original author.

![image courtesy of the original author](https://i.imgur.com/tWrOwXs.png)

The implementation is omitted, if you are interested go to the repo.

The filter outputs oo and aa, which is then mixed back into the original signal. All of these parameters can be tweaked just like on a real physical pedal.

# Tuner

What good is an effect processor if it doesn't have a tuner? Admittedly, I never use these but wrote one for the sake of completeness. This is very straightforward Fourier transform based pitch detector. It converts the signals from time domain into frequency domain and finds the maximum frequency. Originally, the input of the transform was the 128 signals and it took me a while to realize that would only output 64 distinct discrete frequencies which are way too few. The resulting count is half because of symmetry of cos(t) = e^(it) + e^(-it). So I created a buffer but then found out it took way too long (30ms). Finally, I moved the tuner to run in a separate thread so it doesn't block.

```rust
static TUNER_BUFFER_SIZE : usize = 10240;

use std::time::Instant;
use std::thread;

extern crate rustfft;
use effects::{CtrlMsg, Effect};
use self::rustfft::FFTplanner;
use self::rustfft::num_complex::Complex;
use self::rustfft::num_traits::Zero;

pub fn calculate_spectrum(samples: &[f32]) -> Vec<f32> {
    let now = Instant::now();

    let mut input: Vec<Complex<f32>> = samples.iter()
        .map(|&x| Complex::new(x, 0.0))
        .collect();

    let mut output: Vec<Complex<f32>> = vec![Complex::zero(); input.len()];

    let mut planner = FFTplanner::new(false);
    let fft = planner.plan_fft(input.len());
    fft.process(&mut input, &mut output);

    println!("{:?}", now.elapsed());

    output.iter()
        .map(|&c| c.norm_sqr())
        .collect()
}

pub fn tune(input: &[f32], sample_rate: usize) -> Option<f32> {

    let input_len = input.len();
    let freqs = calculate_spectrum(input);

    let buckets: Vec<_> =
        (0 .. 1 + input_len / 2) // has Hermitian symmetry to f=0
        .filter_map(|i| {
            let norm = freqs[i];
            let noise_threshold = 1.0;
            if norm > noise_threshold {
                let f = i as f32 / input_len as f32 * sample_rate as f32;
                Some((f, norm))
            } else {
                None
            }
        })
        .collect();

    if buckets.is_empty() {
        return None
    }

    let &(max_f, _max_val) =
        buckets.iter()
        .max_by(|&&(_f1, ref val1), &&(_f2, ref val2)| val1.partial_cmp(val2).unwrap())
        .unwrap();
    println!("Freq is {}", max_f);
    Some(max_f)
}

```

# Putting everything together

Finally, I want to chain several effects together, change connections, tweak parameters on the fly. To do this, I store the connections in a graph. And based on the graph definition dynamically dispatch computation by looking up from a hashmap of `Box<Effect>`. I also wrote a little command parser to do things like `c in tuner autowah delay out` which daisy chains everything from in to out. At this point, I was pretty bored, ready to liquidate my learns and forget about this weekend hack.

# More

I would love to add vocoder which applies pitch shift to mic input based on guitar notes.

## Conclusion

In an effort to experiment with dsp, I wrote a guitar/bass effects processor this past weekend. The end result works very well(to my pleasant surprise). It doesn't have 90% of the functionalities of any of rakarrack, guitar rig, garage band but overall it was a fun weekend hack.


# [If you find this article helpful, you should sign up to get updates.](https://tinyletter.com/rickyhan)
