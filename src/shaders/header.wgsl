@group(0) @binding(0) var<storage, read_write> framebuffer : array<vec4f>;
@group(0) @binding(1) var<uniform> uniforms : Uniforms;
@group(0) @binding(2) var<storage, read> sphere_objs : array<Sphere>;

const PI = 3.1415926535897932385;
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

struct Sphere {
  center: vec3f,
  radius: f32,
}

struct HitRecord {
  p: vec3f,
  t: f32,
  normal: vec3f,
  front_face: bool,
  // TODO material
}

var<private> NUM_SPHERES : i32;
var<private> rand_state : u32 = 0u;
var<private> pixel_coords : vec3f;
var<private> fov_factor : f32;
var<private> cam_origin: vec3f;