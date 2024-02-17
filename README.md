# HOORAY!

A Zig port of the "Ray tracing in one weekend" series.

Built using mach-core and zig-gamedev libraries.

Current shaders are taken from https://github.com/Shridhar2602/WebGPU-Path-Tracer

## TODO

### First connections steps
Sphere / Quads structures don't match with what I have in the shaders.
Maybe I can carry that data in a wrapper? or I can transform the shapes beforehand
Then I need to reenable the other buffers and see what happens

#### Flow from WebGPU-Path-Tracer
In initBuffers calls `scene.create_bvh`
Then `scene.get_bvh` which is put into the buffer

##### scene.create_bvh
- gets the flattened triangles in the scene
- builds the bvh out of flattened triangles by calling `builder.build_bvh`
- saves the scene triangles
- saves the flattened `bvh_array`

###### builder.build_bvh
- calls `BVH.create_bvh`
- calls `BVH.populate_links`
- calls `builder.flattenBVH`
- does some weird operation to the flattened array at some specific indexes
- returns both the bvh and the flattened one

##### scene.get_bvh
Returns the flattened bvh as an array of f32


### Camera
- The moveCamera function will have to be designed in a completely different way.

### Random notes

## Done

The basic structure is down.
There are a few things that I still have to understand, and then there's the 
big problem of serializing my structures correctly for the fragments.
