---
layout: post
title:  "Fun weekend hack: cool effects pedals"
date:   2018-02-06 00:00:00 -0400
categories: jekyll update
---

A guitar effect alters how the input sounds by adding distortion, delaying signal, shifting pitch/frequency and changing dynamics and loudness. Most physical pedals are analog - altering the electric signals directly, with non-existent latency. Digital effects sample the source input at high frequencies(44100 Hertz) and quickly process using DSP algorithms so it appears live.

My project uses JACK which stands for **JACK Audio Connection Kit** and uses the abstraction of port, or plug, socket, jack. The idea is writing a program that registers input and output ports on JACK server and processes audio as it comes in. So I googled around and found [rust-jack](https://github.com/RustAudio/rust-jack) and quickly got audio playback to work.

# Setup

I first booted up a server with `qjackctl` and changed the setup to lower the latency(bottom right corner).

![qjackctl](https://i.imgur.com/7052cHF.png)

Then the playback example from `rust-jack` works and the audio appears live:

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

This trait defines the minimum set of methods for an effect struct. Note that Effect needs to be `Send` for it to cross thread boundary and move into the closure and `Sized` for it to be a [trait object](https://doc.rust-lang.org/book/first-edition/trait-objects.html#object-safety).

A simple Effect implementing this trait is Overdrive:

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

This effect doubles signals whose absolute values are <= 1/3. This includes the eddy currents produced by guitar pickup. It uses a symmetrical soft clipping quadratic equation to amplify the middle parts. It sounds exactly like the overdrive button on my amp.

Here is a graph for the transformation for signals with aboslute between 1/3 and 2/3.

![middle transformation](https://i.imgur.com/sS2Bwwt.png)

# Delay 

After a taste of overdrive, I wanted to implement a time-dependent effect. A delay of 0.2 second with 0.3 feedback means an echo of amplitude 0.3 of the original after 0.2 seconds. And then another signal of amplitude of 0.09 after 0.4.

This can be done in 2 ways:

1. Convolve the original signal with an impulse response. See this excellent [talk](https://youtu.be/HTfa2UF_oiI?t=27m53s). However, this is out of scope for our purpose.
2. Use a longer buffer and add an attenuated signal from t samples before. A good data structure for this is a ring buffer.

This is the implementation for this effect(explanation below):

```rust
use effects::{Effect, CtrlMsg};

pub struct Delay {
    pub bypassing: bool,
    delay_buffer: Vec<f32>,
    delay_buffer_size: usize,
    feedback: f32,
    writer_idx: usize,
    reader_idx: usize,
    sample_rate: usize,
    delay_time: usize,
    frame_size: u32,
}

impl Delay {
    /// t in seconds
    pub fn set_delay(&mut self, t: f32) {
        let delay_time = (t * self.sample_rate as f32) as usize;
        assert!(delay_time < self.delay_buffer_size);
        self.delay_time = delay_time;
    }
    pub fn set_feedback(&mut self, f: f32) {
        assert!(f < 1.); // multiplying by > 1 would be too loud
        self.feedback = f;
    }
}

impl Effect for Delay {
    fn new(sample_rate: usize, frame_size: u32) -> Self {
        let delay_buffer_size = sample_rate; // we keep 1 second of previous signals values
        Delay {
            bypassing: false,
            delay_buffer_size,
            delay_buffer: vec![0.; delay_buffer_size],
            feedback: 0.3,
            writer_idx: 0,
            reader_idx: 0,
            delay_time: 8820,
            sample_rate,
            frame_size
        }
    }
    fn name(&self) -> &str {
        "delay"
    }
    fn process_samples(&mut self, input: &[f32], output_l: &mut [f32], output_r: &mut [f32]) {
        if self.bypassing {
            output_l.clone_from_slice(input);
            output_r.clone_from_slice(input);
            return;
        }
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
    }
    fn bypass(&mut self) {
        self.bypassing = !self.bypassing;
    }
    fn is_bypassing(&self) -> bool {
        self.bypassing
    }
    fn ctrl(&mut self, msg: CtrlMsg) {
        use self::CtrlMsg::*;
        match msg {
            Bypass => self.bypass(),
            Set(_pedal_name, conf_name, val) => {
                if &conf_name == "feedback" {
                    self.set_feedback(val);
                } else if &conf_name == "delay" {
                    self.set_delay(val);
                }
            },
            _ => (),
        }
    }
}
```

This effect uses a ring buffer which is a fixed sized vector for streaming data. It overwrites data in the front when a pointer reached the end. A notable property of the ring buffer is that it's lock-free thread safe as long as there is only one reader and one writer whose roles cannot be interchanged and writer pointer never catches up with reader pointer. The difference between writer and reader pointers is always the delayed samples. The rest is trivial.

# Auto Wah

Auto Wah is my personal favorite(vocoder is second). The idea is simple: filter controlled by envelope follower. The louder the sound, the more oo, and conversely aa. The filter can be tweaked to achieve different vowels. It outputs human sounding vowels voices like ooii(highpass filter), ooaa(bandpass), ooee(lowpass). Unlike a conventional wah pedal, it only responds to the volume of the input signal so buffers are not necessary. I ported the code from a C++ implementation found on [github](https://github.com/dangpzanco/autowah).

![image courtesy of the original author](https://i.imgur.com/tWrOwXs.png)

```rust
use effects::{CtrlMsg, Effect};
use std::default::Default;
use std::f32::consts::PI as pi;

const sinConst3: f32 = -1. / 6.;
const sinConst5: f32 = 1. / 120.;
const tanConst3: f32 = 1. / 3.;
const tanConst5: f32 = 1. / 3.;
fn sin(x: f32) -> f32 {
    x * (1. + sinConst3 * x * x)
}
fn precisionSin(x: f32) -> f32 {
    let x2 = x * x;
    let x4 = x2 * x2;
    x * (1. + sinConst3*x2 + sinConst5*x4)
}
fn tan(x: f32) -> f32 {
    x * (1. + tanConst3*x*x)
}
fn precisionTan(x: f32) -> f32 {
    let x2 = x * x;
    let x4 = x2 * x2;
    x * (1. + tanConst3*x2 + tanConst5*x4)
}

#[derive(Default)]
pub struct AutoWah {
    bypassing: bool,
    frame_size: u32,

    // Level Detector parameters
    alphaA: f32,
    alphaR: f32,
    betaA: f32,
    betaR: f32,
    bufferL: (f32, f32),

    // Lowpass filter parameters
    bufferLP: f32,
    gainLP: f32,

    // State Variable Filter parameters
    minFreq: f32,
    freqBandwidth: f32,
    q: f32,
    sample_rate: f32,
    centerFreq: f32,
    yHighpass: f32,
    yBandpass: f32,
    yLowpass: f32,
    filter: FilterType,

    // Mixer parameters
    alphaMix: f32,
    betaMix: f32,
}

impl Effect for AutoWah {
    fn new(sample_rate: usize, frame_size: u32) -> Self {
        let mut aw = AutoWah {
            bypassing: false,
            sample_rate: sample_rate as f32,
            frame_size,
            ..Default::default()
        };

        aw.set_attack(0.04);
        aw.set_release(0.002);
        aw.set_min_maxFreq(20., 3000.);
        aw.set_quality_factor(1. / 5.);
        aw.set_mixing(0.8);

        aw
    }

    fn name(&self) -> &str {
        "autowah"
    }

    fn process_samples(&mut self, input: &[f32], output_l: &mut [f32], output_r: &mut [f32]) {
        for i in 0..self.frame_size as usize {
            let x = input[i] * 1.;
            let mut y = self.run_effect(x) * 2.;

            if y > 1. {y = 1.;}
            else if y < -1. {y = -1.;}

            output_l[i] = y;
            output_r[i] = y;
        }
    }

    fn bypass(&mut self) {
        self.bypassing = !self.bypassing;
    }

    fn is_bypassing(&self) -> bool {
        self.bypassing
    }

    fn ctrl(&mut self, msg: CtrlMsg) {
        match msg {
            _ => (),
        }
    }
}

impl AutoWah {
    pub fn run_effect(&mut self, x: f32) -> f32 {
        let xL = x.abs();

        let yL = self.level_detector(xL);

        //fc = yL * (maxFreq - minFreq) + minFreq;
        self.centerFreq = yL * self.freqBandwidth + self.minFreq;

        //float xF = x;
        let xF = self.low_pass_filter(x);
        let yF = self.state_variable_filter(xF);

        let y = self.mixer(x, yF);

        return y;
    }

    pub fn set_filter_type(&mut self, typ: FilterType) {
        self.filter = typ;
    }
    pub fn set_attack(&mut self, tauA: f32) {
        self.alphaA = (-1. / tauA / self.sample_rate ).exp();
        self.betaA = 1. - self.alphaA;
    }
    pub fn set_release(&mut self, tauR: f32) {
        self.alphaR = (-1. / tauR / self.sample_rate ).exp();
        self.betaR = 1. - self.alphaA;
    }
    pub fn set_min_maxFreq(&mut self, minFreq: f32, maxFreq: f32) {
        self.freqBandwidth = pi * (2. * maxFreq - minFreq) / self.sample_rate;
        self.minFreq = pi * minFreq / self.sample_rate;
    }
    pub fn set_sample_rate(&mut self, sample_rate: f32) {
        self.sample_rate = sample_rate;
    }
    pub fn set_quality_factor(&mut self, Q: f32) {
        self.q = Q;
        self.gainLP = (0.5 * Q).sqrt();
    }
    pub fn set_mixing(&mut self, alphaMix: f32) {
        self.alphaMix = alphaMix;
        self.betaMix = 1. - alphaMix;
    }
    fn level_detector(&mut self, x: f32) -> f32 {
        let y1 = self.alphaR * self.bufferL.1 + self.betaR * x;
        if x > y1 { self.bufferL.1 = x; }
        else      { self.bufferL.1 = y1;}

        self.bufferL.0 = self.alphaA * self.bufferL.0 + self.betaA * self.bufferL.1;

        return self.bufferL.0;
    }
    fn low_pass_filter(&mut self, x: f32) -> f32 {
        let K = tan(self.centerFreq);
        let b0 = K / (K + 1.);
        let a1 = 2.0 * (b0 - 0.5);

        let xh = x - a1 * self.bufferLP;
        let y = b0 * (xh + self.bufferLP);
        self.bufferLP = xh;

        return self.gainLP * y;
    }
    fn state_variable_filter(&mut self, x: f32) -> f32{
        let f = 2.0 * sin(self.centerFreq);
        self.yHighpass  = x - self.yLowpass - self.q * self.yBandpass;
        self.yBandpass += f * self.yHighpass;
        self.yLowpass  += f * self.yBandpass;

        use self::FilterType::*;
        match self.filter {
            Lowpass => self.yLowpass,
            Bandpass => self.yBandpass,
            Highpass => self.yHighpass,
        }
    }
    fn mixer(&self, x: f32, y: f32) -> f32 {
        self.alphaMix * y + self.betaMix * x
    }
}

enum FilterType {
    Lowpass,
    Bandpass,
    Highpass
}

impl Default for FilterType {
    fn default() -> Self {
        FilterType::Bandpass
    }
}
```

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

pub struct Tuner {
    tuner_buffer: Vec<f32>,
    i_idx: usize,
    bypassing: bool,
    sample_rate: usize,
    frame_size: u32,
}

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


    println!("Max index is {}", max_f);

    Some(max_f)
}

impl Effect for Tuner {

    fn new(sample_rate: usize, frame_size: u32) -> Self {
        Self {
            tuner_buffer: vec![0.; TUNER_BUFFER_SIZE],
            i_idx: 0,
            bypassing: true,
            sample_rate,
            frame_size
        }
    }

    fn name(&self) -> &str {
        "tuner"
    }

    fn process_samples(&mut self, input: &[f32], output_l: &mut [f32], output_r: &mut [f32]) {

        for bufptr in 0..self.frame_size as usize {
            if self.i_idx >= TUNER_BUFFER_SIZE {
                self.i_idx = 0;
            }
            self.tuner_buffer[self.i_idx] = input[bufptr];
            self.i_idx += 1;

            output_l[bufptr] = input[bufptr];
            output_r[bufptr] = input[bufptr];
        }

    }

    fn bypass(&mut self) {
        ()
    }

    fn is_bypassing(&self) -> bool {
        self.bypassing
    }

    fn ctrl(&mut self, msg: CtrlMsg) {
        use self::CtrlMsg::*;
        match msg {
            Bypass => self.bypass(),
            Tuner => {
                let input = self.tuner_buffer.to_owned();
                let sample_rate = self.sample_rate;
                thread::spawn(move || {
                    tune(&input, sample_rate);
                });
            },
            _ => (),
        }
    }

}
```

# Putting everything together

Finally, I want to chain several effects together, change connections, tweak parameters on the fly. To do this, I store the connections in a graph. And based on the graph definition dynamically dispatch computation by looking up from a hashmap of `Box<Effect>`. I also wrote a little command parser to do things like `c in tuner autowah delay out` which daisy chains everything from in to out. At this point, I was pretty bored, ready to liquidate my learns and forget about this weekend hack.

```rust
use effects::*;
use std::collections::HashMap;

pub struct Pedals {
    sample_rate: usize,
    frame_size: u32,
    pub pedals: HashMap<String, Box<Effect>>,
    pub bypassing: bool,
    /// in -> eff1 -> eff2 -> out
    chain: HashMap<String, String>,
}

impl Effect for Pedals {

    fn new(sample_rate: usize, frame_size: u32) -> Self {
        Pedals {
            sample_rate,
            frame_size,
            pedals: HashMap::new(),
            bypassing: false,
            chain: HashMap::new(),
        }
    }

    fn name(&self) -> &str {
        "effects"
    }

    fn process_samples(&mut self, input: &[f32], output_l: &mut [f32], output_r: &mut [f32]) {

        if self.bypassing {
            output_l.clone_from_slice(input);
            output_r.clone_from_slice(input);
            return;
        }

        let mut next_node = {
            let temp = self.chain.get("in");
            if temp.is_none() {
                return;
            } else {
                temp.unwrap()
            }
        };

        let mut temp_buf = input.to_owned();

        while *next_node != "out" {
            let eff = self.pedals.get_mut(next_node);
            let eff = if eff.is_none() {
                break
            } else {
                eff.unwrap()
            };
            // if eff.is_bypassing() { continue; }

            eff.process_samples(&temp_buf, output_l, output_r);
            temp_buf = output_l.to_owned();

            let next = self.chain.get(next_node);

            next_node = if next.is_none() {
                break
            } else {
                next.unwrap()
            };
        }

        output_l.clone_from_slice(&temp_buf);
        output_r.clone_from_slice(&temp_buf);

    }
    fn bypass(&mut self) {
        self.bypassing = !self.bypassing;
        println!("Bypassing: {}", self.bypassing);
    }
    fn is_bypassing(&self) -> bool {
        self.bypassing
    }
    fn ctrl(&mut self, msg: CtrlMsg) {
        use self::CtrlMsg::*;
        match msg {
            Bypass => self.bypass(),
            BypassPedal(name) => {
                let mut pedal = self.pedals.get_mut(&name).unwrap();
                (*pedal).ctrl(Bypass);
            }
            Tuner => {
                let mut tuner = self.pedals.get_mut("tuner").unwrap();
                (*tuner).ctrl(msg);
            },
            Connect(from, to) => {
                self.connect(&from, &to)
            },
            Disconnect(from) => {
                self.disconnect(&from)
            },
            Connections => self.print_conn(),
            Add(name, eff_type) => {
                let eff : Box<Effect> = match eff_type.as_str() {
                    "delay" =>      box delay::Delay::new(self.sample_rate, self.frame_size),
                    "overdrive" =>  box overdrive::Overdrive::new(self.sample_rate, self.frame_size),
                    "tuner" =>      box tuner::Tuner::new(self.sample_rate, self.frame_size),
                    "autowah" =>    box autowah::AutoWah::new(self.sample_rate, self.frame_size),
                    &_ => unimplemented!()
                };
                self.add(&name, eff);
            },
            Set(name, conf, val) => {
                let mut pedal = self.pedals.get_mut(&name).unwrap();
                (*pedal).ctrl(Set(name, conf, val));
            },
            Chain(v) => {
                for i in v.into_iter() {
                    self.ctrl(i);
                }
            }
        }
    }
}
impl Pedals {
    pub fn add(&mut self, name: &str, eff: Box<Effect>) {
        self.pedals.insert(name.to_owned(), eff);
    }
    pub fn connect(&mut self, from: &str, to: &str) {
        self.chain.insert(from.to_owned(), to.to_owned());
    }
    pub fn disconnect(&mut self, from: &str) {
        self.chain.remove(from);
    }
    pub fn print_conn(&self) {
        print!("Chain: ");
        let mut node = "in";
        while node != "out" && self.chain.contains_key(node) {
            print!("{} -> ", node);
            node = self.chain.get(node).unwrap();
        }
        println!("out");
        println!("Graph: {:?}", self.chain);
        println!("Pedals: {:?}", self.pedals.keys().collect::<Vec<_>>())
    }
}
```

And here is the command parser:

```rust
use effects::CtrlMsg;

pub fn parse_input(cmd: &str) -> CtrlMsg {
    use self::CtrlMsg::*;

    if cmd == "t" {
        Tuner
    } else

    if cmd == "b" {
        Bypass
    } else

    if cmd.starts_with("b") {
        let tokens = cmd[2..]
            .split(" ")
            .collect::<Vec<&str>>();
        let mut chain = vec![];
        for token in tokens.into_iter() {
            chain.push(BypassPedal(token.to_owned()));
        }
        Chain(chain)
    } else

    if cmd == "p" {
        Connections
    } else

    if cmd.starts_with("d") {
        let tokens = cmd[2..]
            .split(" ")
            .collect::<Vec<&str>>();
        let mut chain = vec![];
        for a in tokens.into_iter() {
            chain.push(Disconnect(a.to_owned()));
        }
        Chain(chain)
    } else

    if cmd.starts_with("s") {
        let tokens = cmd[2..]
            .split(" ")
            .collect::<Vec<&str>>();
        let pedal_name = tokens[0].to_owned();
        let conf_name = tokens[1].to_owned();
        let val = tokens[2].parse::<f32>().unwrap();
        Set(pedal_name, conf_name, val)
    } else
    
    if cmd.starts_with("c") {
        // allow daisy chaining:
        // c in delay overdrive out
        let tokens = cmd[2..]
            .split(" ")
            .collect::<Vec<&str>>();

        let mut chain = vec![];
        for (a, b) in tokens.iter().zip(tokens[1..].into_iter()) {
            let inp = a.to_owned().to_owned();
            let outp = b.to_owned().to_owned();

            chain.push(Connect(inp, outp))
        }

        Chain(chain)
    } else
    
    if cmd.starts_with("a") {
        let tokens = cmd.split(" ").collect::<Vec<&str>>();
        let name = tokens[1].to_owned();
        let eff_type = tokens[2].to_owned();

        Add(name, eff_type)

    } else {
        Bypass
    }
}
```



## Conclusion

In an effort to experiment with dsp, I wrote a guitar/bass effects processor last weekend. Although I spent a little too much time on the tuner, the end result works very well(to my pleasant surprise). It doesn't have 90% of the functionalities of any one of rakarrack, guitar rig, garage band but overall it was a fun weekend hack.


# [If you find this article helpful, you should sign up to get updates.](https://tinyletter.com/rickyhan)
