# HOORAY!

A Zig port of the "Ray tracing in one weekend" series.

Built using mach-core and zig-gamedev libraries.

Current shaders are taken from https://github.com/Shridhar2602/WebGPU-Path-Tracer

## TODO

### Shaders
Keep on adding the shaders.

### Aabb_GPU
I need to read this and check hitRay to figure out what the right offset and other nodes are supposed to be.
https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/):

### Camera
- The moveCamera function will have to be designed in a completely different way.

### Random notes

## Done

The basic structure is down.
There are a few things that I still have to understand, and then there's the 
big problem of serializing my structures correctly for the fragments.
