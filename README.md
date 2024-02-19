# HOORAY!

A Zig port of the "Ray tracing in one weekend" series.

Built using mach-core and zig-gamedev libraries.

Current shaders are taken from https://github.com/Shridhar2602/WebGPU-Path-Tracer

## TODO

### BVH
Finish reconciling the [book](https://pbr-book.org/4ed/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies) implementation to what I had before.
I moved the old implementation to ref-bvhs.zig
Plausible steps:
- [ ] A couple of calls in the generator functions are commented and I need to figure out how to handle them.
- [X] flattenBVH needs to return the correct fields (I'm not sure about them all) for Aabb_GPU
- [X] call the new functions from scene
- [ ] test it with one object only
- [ ] implement the missing else part in the generator function
- [ ] once everything is fine, cleanup

I've wired a few more things, but initBuffers is crashing the app.
I think I need all buffers to be filled? Weird though.

https://github.com/mmp/pbrt-v4/blob/master/src/pbrt/cpu/aggregates.h
https://github.com/mmp/pbrt-v4/blob/master/src/pbrt/cpu/aggregates.cpp

### Shaders
Keep on adding the shaders.

### Camera
- The moveCamera function will have to be designed in a completely different way.

### Random notes

## Done

The basic structure is down.
There are a few things that I still have to understand, and then there's the 
big problem of serializing my structures correctly for the fragments.
