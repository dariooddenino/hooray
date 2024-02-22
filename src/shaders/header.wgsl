@group(0) @binding(0) var<storage, read_write> framebuffer : array<vec4f>;
@group(0) @binding(1) var<uniform> uniforms : Uniforms;

const NUM_SAMPLES = 1;
const MAX_BOUNCES = 100;

struct Uniforms {
  screen_dims: vec2f,
  frame_num: f32,
  reset_buffer: f32,
  view_matrix: mat4x4f,
}

struct Ray {
  origin: vec3f,
  direction: vec3f,
}

var<private> rand_state : u32 = 0u;
var<private> pixel_coords : vec3f;
var<private> fov_factor : f32;
var<private> cam_origin: vec3f;