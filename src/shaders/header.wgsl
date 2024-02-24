@group(0) @binding(0) var<storage, read_write> framebuffer : array<vec4<f32>>;
@group(0) @binding(1) var<uniform> uniforms : Uniforms;
@group(0) @binding(2) var<storage, read> sphere_objs : array<Sphere>;

const PI = 3.1415926535897932385;
const MIN_FLOAT = 0.0001;
const MAX_FLOAT = 999999999.999;
const NUM_SAMPLES = 1;
const MAX_BOUNCES = 1;

struct Uniforms {
  screen_dims: vec2<f32>,
  frame_num: f32,
  reset_buffer: f32,
  view_matrix: mat4x4<f32>,
}

struct Ray {
  origin: vec3<f32>,
  direction: vec3<f32>,
}

struct Sphere {
  center: vec3<f32>,
  radius: f32,
}

struct HitRecord {
  p: vec3<f32>,
  t: f32,
  normal: vec3<f32>,
  front_face: bool,
  // TODO material
}

var<private> NUM_SPHERES : i32;
var<private> rand_state : u32 = 0u;
var<private> pixel_coords : vec3<f32>;
var<private> fov_factor : f32;
var<private> cam_origin: vec3<f32>;
var<private> hit_rec : HitRecord;
var<private> ray_tmin : f32 = 0.000001;
var<private> ray_tmax : f32 = MAX_FLOAT;
