@group(0) @binding(0) var<storage, read_write> framebuffer : array<vec4<f32>>;
@group(0) @binding(1) var<uniform> uniforms : Uniforms;
@group(0) @binding(2) var<storage, read> materials: array<Material>;
@group(0) @binding(3) var<storage, read> sphere_objs : array<Sphere>;

const PI = 3.1415926535897932385;
const MIN_FLOAT = 0.0001;
const MAX_FLOAT = 999999999.999;
const LAMBERTIAN = 0;
const MIRROR = 1;
const GLASS = 2;
const ISOTROPIC = 3;
const ANISOTROPIC = 4;
const MAX_SAMPLES = 50;
const MAX_BOUNCES = 30;

struct Uniforms {
  screen_dims: vec2<f32>,
  frame_num: f32,
  reset_buffer: f32,
  view_matrix: mat4x4<f32>,
  eye: vec3<f32>,
}

struct Ray {
  origin: vec3<f32>,
  direction: vec3<f32>
}

struct Material {
  color: vec3<f32>,
  specular_color: vec3<f32>,
  emission_color: vec3<f32>,
  specular_strength: f32,
  roughness: f32,
  eta: f32,
  material_type: f32
}

struct Sphere {
  center: vec3<f32>,
  radius: f32,
  material_id: f32,
}

struct HitRecord {
  p: vec3<f32>,
  t: f32,
  normal: vec3<f32>,
  front_face: bool,
  material: Material
}

struct ScatterRecord {
  pdf: f32,
  skip_pdf: bool,
  skip_pdf_ray: Ray,
}

var<private> NUM_SPHERES : i32;
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
