---
layout: post
title:  "Gradient Trader Part 4: Build Training Set with Rust for Python"
date:   2017-11-16 00:00:00 -0400
categories: jekyll update
---

Preparing dataset for machine learning is a CPU heavy task. To optimize for GPU utilization during training, it is imperative to process the data before training. What is the proper way to approach this? Depends on how much data you have.

Recently, I trained a new model. I had 60GB [compressed](http://rickyhan.com/jekyll/update/2017/10/27/how-to-handle-order-book-data.html) order book data with which I needed to generate a 680GB training set.

This post is about the awkward situation where the dataset is not big enough to warrant Spark but would take too long to run on your computer. A top-end deep learning box only has a maximum of 32 cores while AWS has 128 cores on demand for $13.388/hr. A simple back-of-the-envelop calculation shows that if a task takes 24 hours on an Intel i7 with 8 threads, or `24 * 8 (hour x thread)` then it would only take ~1 hour to run on a 128 core instance for the price of a burrito. Another pro is the huge memory(1952GB) that should fit most datasets.

I use Rust to do the heavy lifting and in this post I will cover these two aspects:

1. Using multiple cores

2. Saving to Numpy format

# Parallel Programming

I suck at writing parallel code. About 4 months ago, I wrote this monstrocity. Feel free to skip it.

```python
import multiprocessing
import tensorflow as tf
from functools import partial
import gc

def _bytes_feature(value):
    return tf.train.Feature(bytes_list=tf.train.BytesList(value=[value]))

batch_size = 256
time_steps = 256
max_scale = max(SCALES)
min_padding = max_scale * time_steps
maximum_sequential_epoch_sequence = range(get_min_epoch(), get_max_epoch(), 60)
ok_epochs = set(maximum_sequential_epoch_sequence[min_padding:-min_padding])
# ok_epochs = set(list(ok_epochs)[:len(ok_epochs)/8])
# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8   : len(ok_epochs)/8*2])
# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8*2 : len(ok_epochs)/8*3])
# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8*3 : len(ok_epochs)/8*4])

# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8*4 : len(ok_epochs)/8*5])
# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8*5 : len(ok_epochs)/8*6])
# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8*6 : len(ok_epochs)/8*7])
# ok_epochs = set(list(ok_epochs)[len(ok_epochs)/8*7 : ])

def gen_all_the_tf_records(n, myepochs):
    tfrecords_filename = '/home/ubuntu/tfrecords/5/{}.tfrecords'.format(n)
    writer = tf.python_io.TFRecordWriter(tfrecords_filename)
    for random_epochs in tqdm(myepochs):
        features = [redacted]
        minibatch = np.stack(features, axis=0)

        example = tf.train.Example(features=tf.train.Features(feature={
            'minibatch': _bytes_feature(minibatch.tostring())
        }))
        writer.write(example.SerializeToString())
        gc.collect()
    writer.close()


def tfrecords_cli():
    global ok_epochs
    iterable = range(len(ok_epochs) / batch_size)
    arrs = []
    threads = 35
    for _ in range(threads):
        arrs.append([])

    for i, _ in tqdm(enumerate(iterable)):
        for arr_i in range(threads):
            if batch_size > len(ok_epochs):
                break
            rand = random.sample(ok_epochs, batch_size)
            arrs[arr_i].append(rand)
            ok_epochs -= set(rand)
    gc.collect()
    ps = []
    for i in range(threads):
        p = multiprocessing.Process(
            target=gen_all_the_tf_records, args=(i, arrs[i]))
        ps.append(p)
    for i, p in enumerate(ps):
        print i , "started"
        p.start()
```

Notice how the `ok_epochs` are changed during every run because it just wouldn't fit into memory. This piece of crap worked and I don't want to talk about it.

Compare it to Rayon, parallelization requires virtually no change. This example is taken from [here](http://smallcultfollowing.com/babysteps/blog/2015/12/18/rayon-data-parallelism-in-rust/).

```rust
// sequential
let total_price = stores.iter()
                        .map(|store| store.compute_price(&list))
                        .sum();
// parallel
let total_price = stores.into_par_iter()
                        .map(|store| store.compute_price(&list))
                        .sum();
```

When I tested Rayon on my laptop, it *really* was 4x as fast. This is about as easy it gets when it comes to multi-core programming.

# Using Numpy format

I save minibatches in [numpy binary format](https://docs.scipy.org/doc/numpy-1.13.0/neps/npy-format.html).

To restore a numpy array from disk:

```
import numpy as np
minibatch = np.load("minibatch.npy")
```

Again, minimal coding required and no tfrecords involved.

Since I'm dealing with spatial-temporal data(for RNN), I need to generate feature tensor of shape `[batch_size, time_step, input_dim]`. To do this, I wrote a serializer for the `npy` format.

```rust
// write_npy.rs
use byteorder::{BE, LE, WriteBytesExt};
use std::io::Write;

use record::*;

static MAGIC_VALUE : &[u8] = &[0x93, 0x4E, 0x55, 0x4D, 0x50, 0x59];

fn get_header() -> String {
    {%raw%}format!("
      {{'descr': [('data', '>f4')],'fortran_order': False,'shape': ({},{},{})}}",
        BATCH_SIZE, TIME_STEP, INPUT_DIM){%endraw%}
}

/// these are just from the spec
pub fn write(wtr: &mut Write, record: &Record) {
    let _ = wtr.write(MAGIC_VALUE);
    let _ = wtr.write_u8(0x01); // major version
    let _ = wtr.write_u8(0x00); // minor version
    let header = &get_header();
    let header_len = header.len();
    let _ = wtr.write_u16::<LE>(header_len as u16);
    let _ = wtr.write(header.as_bytes()); // header

    for batch in record.iter() {
        for step in batch.iter() {
            for input in step.iter() {
                let _ = wtr.write_f32::<BE>(*input);
            }
        }
    }
}
```

```rust
// record.rs
pub const INPUT_DIM: usize = 6;
pub const TIME_STEP: usize = 5;
pub const BATCH_SIZE: usize = 4;

// shape [batch_size, time_step, input_dim]
pub type Record = [[[ f32 ; INPUT_DIM]; TIME_STEP]; BATCH_SIZE];
```

```rust
// main.rs

extern crate byteorder;
mod write_npy;
mod record;

use record::*;
use std::io::BufWriter;
use std::fs::File;

fn main() {
    let fname = "minibatch.npy";
    let new_file = File::create(fname).unwrap();
    let mut wtr = BufWriter::new(new_file);

    let mut record = [[[ 0_f32 ; INPUT_DIM]; TIME_STEP]; BATCH_SIZE];
    for batch in 0..BATCH_SIZE {
        for step in 0..TIME_STEP {
            for dim in 0..INPUT_DIM {
                record[batch][step][dim] =
                  (100 * batch + 10 * step + 1* dim) as f32;
            }
        }
    }

    write_npy::write(&mut wtr, &record);
}
```

Printing the tensor out:

```python
import numpy as np
dataset = np.load("test.npy")
print dataset.shape
print dataset
```

```python
    (4, 5, 6)
    [[[(   0.,) (   1.,) (   2.,) (   3.,) (   4.,) (   5.,)]
    [(  10.,) (  11.,) (  12.,) (  13.,) (  14.,) (  15.,)]
    [(  20.,) (  21.,) (  22.,) (  23.,) (  24.,) (  25.,)]
    [(  30.,) (  31.,) (  32.,) (  33.,) (  34.,) (  35.,)]
    [(  40.,) (  41.,) (  42.,) (  43.,) (  44.,) (  45.,)]]

    [[( 100.,) ( 101.,) ( 102.,) ( 103.,) ( 104.,) ( 105.,)]
    [( 110.,) ( 111.,) ( 112.,) ( 113.,) ( 114.,) ( 115.,)]
    [( 120.,) ( 121.,) ( 122.,) ( 123.,) ( 124.,) ( 125.,)]
    [( 130.,) ( 131.,) ( 132.,) ( 133.,) ( 134.,) ( 135.,)]
    [( 140.,) ( 141.,) ( 142.,) ( 143.,) ( 144.,) ( 145.,)]]

    [[( 200.,) ( 201.,) ( 202.,) ( 203.,) ( 204.,) ( 205.,)]
    [( 210.,) ( 211.,) ( 212.,) ( 213.,) ( 214.,) ( 215.,)]
    [( 220.,) ( 221.,) ( 222.,) ( 223.,) ( 224.,) ( 225.,)]
    [( 230.,) ( 231.,) ( 232.,) ( 233.,) ( 234.,) ( 235.,)]
    [( 240.,) ( 241.,) ( 242.,) ( 243.,) ( 244.,) ( 245.,)]]

    [[( 300.,) ( 301.,) ( 302.,) ( 303.,) ( 304.,) ( 305.,)]
    [( 310.,) ( 311.,) ( 312.,) ( 313.,) ( 314.,) ( 315.,)]
    [( 320.,) ( 321.,) ( 322.,) ( 323.,) ( 324.,) ( 325.,)]
    [( 330.,) ( 331.,) ( 332.,) ( 333.,) ( 334.,) ( 335.,)]
    [( 340.,) ( 341.,) ( 342.,) ( 343.,) ( 344.,) ( 345.,)]]]
```

Now we can load some of these numpy files with PyTorch:

```python
class orderbookDataset(torch.utils.Dataset):
    def __init__(self):
        self.data_files = os.listdir('data_dir')

    def __getindex__(self, idx):
        return np.load(self.data_files[idx])

    def __len__(self):
        return len(self.data_files)
        
dset = OrderbookDataset()
loader = torch.utils.DataLoader(dset, num_workers=8)
```

## Conclusion

Using Rust to prepare training set is about as easy as it gets. Amazing language

# [If you find this article helpful, you should sign up to get updates.](https://tinyletter.com/rickyhan)
