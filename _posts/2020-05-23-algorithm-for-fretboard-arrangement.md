---
layout: post
title:  "AutoBassTab: A Pipeline for Automatic Bass Tab Transcription"
date:   2020-05-23 00:00:00 -0400
categories: jekyll update
---

## Introduction

Over the past weekend, I hacked together a pipeline to automatically transcribe bass tab from any song. It consists of two neural networks and some heuristics based algorithms. Here is the algorithm in action:

<iframe width="560" height="315" src="https://www.youtube.com/embed/2megT5UU-G0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

<iframe width="560" height="315" src="https://www.youtube.com/embed/_OeHVuvUeE8" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

The main motivation behind this was my obsession with learning obscure reggae basslines from old Jamaican music. After I stumbled across a Hacker News post on [Spleeter](https://news.ycombinator.com/item?id=23228539) a couple days ago, I decided to build a prototype and it turned out to be a huge success.

## The Pipeline

Here are the stages of the pipeline:

1. **[Stem](https://en.wikipedia.org/wiki/Stem_mixing_and_mastering) separation**. This step produces a wav file of bass stem only without other instruments using [Spleeter](https://github.com/deezer/spleeter).

2. **Raise pitch by 1 octave** using `sox $in $out pitch 1200 bass -30 100 gain 10`. This step raises the original track by 12 semitones and removes some overtones.

3. **Melody tracking**. This step produces a frequency estimation and associated confidence for each sample (100ms). Since the role of the bass is to accentuate chord tones, notes are usually played one at a time. A monophonic instrument is a lot easier to track than a polyphonic one(guitar/piano) where several notes are played simultaneously. Melody tracking is an active research area in the field of Music Information Retrieval. After 10 hours of reading, I settled on [crepe](https://github.com/marl/crepe) whose deep learning approach is apparently better than state-of-the-art heuristics based methods such as [pYIN](https://code.soundsoftware.ac.uk/projects/pyin) and [Melodia](http://www.justinsalamon.com/melody-extraction.html).

4. **Note Tracking**. This step produces a sequence of notes with frequency, start and duration. Unfortunately crepe doesn't do note tracking(unlike pYIN), and I couldn't find any deep learning model that does this. I studied the source code of [tony](https://code.soundsoftware.ac.uk/projects/tony) and used a variant of the state space based algorithm.

5. **Fretboard arrangement**. This step converts notes to positions on fretboard. First, separate the sequence of notes into sentences based on whether gap length is longer than 1.5 stddev. Then run a [custom algorithm](https://gist.github.com/0b01/51df8e04dd09a10b557084453a27281e) which uses dynamic programming to minimize biomechanical cost between notes(finger movement, penalizes open string and high frets). On average the same pitch has 3 possible positions on the fretboard, a naive graph search algorithm on a tree with branching factor 3 would give O(3^n) space and time complexity.

6. **Plotting, making video and uploading to youtube**. YouTube has API limits so I can't upload more than 3 videos a day.

The pipeline runs under 5 minutes for a 4 minute song but 90% is in video generation(which is written in Python).

## Conclusion

Although this pipeline is still rough around the edges, it generally outputs sensible results. The arrangement algorithm use a dynamic threshold and should take more things into account such as musical conventions and right hand techniques. I believe the result may be good enough to use as training set for a neural net tuned for note tracking(maybe finetune the weights from crepe?). Having done my (limited) research, I don't think there's a deep learning model that does note tracking so you can definitely write a research paper with this.

The source code for this project is [here](https://github.com/0b01/AutoBassTab)
