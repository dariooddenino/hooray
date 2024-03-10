# HOORAY!

A Zig port of the "Ray tracing in one weekend" series with additions from the pbr-book too.

Built using mach-core and zig-gamedev libraries.

Some inspiration taken from https://github.com/Shridhar2602/WebGPU-Path-Tracer

## Setup
- Clone `zig-gamdev` to /deps

## TODO
### Things I've skipped for now
- [ ] Textures
- [ ] Skyboxes
- [ ] Noise
### Next on the book
- [ ] Instances
- [ ] Volumes
- [ ] Final week 2 scene

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
