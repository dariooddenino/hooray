# HOORAY!

A Zig port of the "Ray tracing in one weekend" series.

Built using mach-core and zig-gamedev libraries.

Current shaders are taken from https://github.com/Shridhar2602/WebGPU-Path-Tracer

## TODO

### BVH
The BVH is sent to a storage buffer after being serialized.
The shader is expecting to receive this data in a specific format, so I 
have to consider whether I want to keep my implementation or switch to
the one 

## Done

The basic structure is down.
There are a few things that I still have to understand, and then there's the 
big problem of serializing my structures correctly for the fragments.
