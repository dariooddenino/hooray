@group(0) @binding(0) var<storage, read_write> framebuffer : array<vec4<f32>>;
@group(0) @binding(1) var<uniform> uniforms : Uniforms;
@group(0) @binding(2) var<storage, read> materials: array<Material>;
@group(0) @binding(3) var<storage, read> bvh: array<AABB>;
@group(0) @binding(4) var<storage, read> objects: array<Object>;
@group(0) @binding(5) var<storage, read> sphere_objs : array<Sphere>;
@group(0) @binding(6) var<storage, read> quad_objs : array<Quad>;
// Triangle
// Meshes
@group(0) @binding(9) var<storage, read> transforms: array<SimpleTransform>;

const PI = 3.1415926535897932385;
const MIN_FLOAT = 0.0001;
const MAX_FLOAT = 999999999.999;
const LAMBERTIAN = 0;
const MIRROR = 1;
const DIELECTRIC = 2;
const ISOTROPIC = 3;
const ANISOTROPIC = 4;
const DIFFUSE_LIGHT = 5;
const NO_OBJ = -1;
const SPHERE = 0;
const QUAD = 1;
const STACK_SIZE = 64;

struct Uniforms {
  frame_num: f32,
  reset_buffer: f32,
  defocus_angle: f32,
  focus_dist: f32,
  sample_rate: i32,
  max_bounces: i32,
  rendering: u32,
  view_matrix: mat4x4<f32>,
  eye: vec3<f32>,
  target_dims: vec2<u32>,
  screen_dims: vec2<u32>,
}

struct Ray {
  origin: vec3<f32>,
  direction: vec3<f32>
}

struct Material {
  color: vec3<f32>,
  material_type: u32,
  specular_color: vec3<f32>,
  specular_strength: f32,
  emission_color: vec3<f32>,
  roughness: f32,
  eta: f32,
}

struct AABB {
  min: vec3<f32>,
  primitive_offset: i32,
  max: vec3<f32>,
  second_child_offset: i32,
  n_primitives: u32,
  axis: f32,
}

struct Object {
  primitive_type: i32,
  primitive_id: u32,
}

struct Sphere {
  center: vec3<f32>,
  radius: f32,
  material_id: f32,
  transform_id: f32,
}

struct Quad {
  Q: vec4<f32>,
  u: vec4<f32>,
  v: vec4<f32>,
  w: vec4<f32>,
  normal: vec4<f32>,
  D: f32,
  material_id: f32,
  transform_id: f32,
}

struct SimpleTransform {
  offset: vec3<f32>,
  sin_theta: f32,
  cos_theta: f32,
}

// struct Transform {
//   model_matrix: mat4x4f,
//   inv_model_matrix: mat4x4f,
// }

struct HitRecord {
  p: vec3<f32>,
  t: f32,
  normal: vec3<f32>,
  front_face: bool,
  material: Material,
  hit_bboxes: u32,
}

struct ScatterRecord {
  pdf: f32,
  skip_pdf: bool,
  skip_pdf_ray: Ray,
}

var<private> NUM_SPHERES : i32;
var<private> NUM_QUADS : i32;
var<private> rand_state : u32 = 0u;
var<private> pixel_coords : vec3<f32>;
var<private> fov_factor : f32;
var<private> cam_origin: vec3<f32>;
var<private> hit_rec : HitRecord;
var<private> scatter_rec : ScatterRecord;
var<private> ray_tmin : f32 = 0.001;
var<private> ray_tmax : f32 = MAX_FLOAT;
var<private> do_specular : f32 = 0.0;
var<private> unit_w: vec3<f32>;
var<private> u: vec3<f32>;
var<private> v: vec3<f32>;
var<private> nodes_to_visit : array<i32, STACK_SIZE>;

