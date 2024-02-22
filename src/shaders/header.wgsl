@group(0) @binding(0) var<storage, read_write> framebuffer : array<vec4f>;
@group(0) @binding(1) var<uniform> uniforms : Uniforms;

struct Uniforms {
  screen_dims: vec2f,
  frame_num: f32,
  reset_buffer: f32,
}