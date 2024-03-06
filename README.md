# HOORAY!

A Zig port of the "Ray tracing in one weekend" series.

Built using mach-core and zig-gamedev libraries.

Current shaders are heavily inspired from https://github.com/Shridhar2602/WebGPU-Path-Tracer

## Setup
- Clone `zig-gamdev` to /deps
- Clone `mach-core` to /deps and switch to the `sysgpu` branch


## TODO
It seems that the linear tree is sent correctly up to the point where it's loaded in the buffer.
I've tested the length on the gpu side, and it should be correct. But I have to investigate more.
If all this is correct, then the problem could be in the tree generation or traversal.
The tree generation, in particualr, has a lot of parts that I'm not sure of.


splitMiddle partition I could avoid sorting?
nthElement? But for now it doesn't even get called
SAH partition? I'm not sure of whats' going on in the book code. Looking at 
the example project might be a better idea.

## Delta time
```zig
/// The time in seconds between the last frame and the current frame.
///
/// Higher frame rates will report higher values, for example if your application is running at
/// 60FPS this will report 0.01666666666 (1.0 / 60) seconds, and if it is running at 30FPS it will
/// report twice that, 0.03333333333 (1.0 / 30.0) seconds.
///
/// For example, instead of rotating an object 360 degrees every frame `rotation += 6.0` (one full
/// rotation every second, but only if your application is running at 60FPS) you may instead multiply
/// by this number `rotation += 360.0 * core.delta_time` which results in one full rotation every
/// second, no matter what frame rate the application is running at.
pub var delta_time: f32 = 0;
pub var delta_time_ns: u64 = 0;
```
