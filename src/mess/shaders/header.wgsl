const PI = 3.1415926535897932385;
const MIN_FLOAT = 0.0001;
const MAX_FLOAT = 999999999.999;
const LAMBERTIAN = 0;
const MIRROR = 1;
const GLASS = 2;
const ISOTROPIC = 3;
const ANISOTROPIC = 4;
const NUM_SAMPLES = 1;
const MAX_BOUNCES = 100;
const STRATIFY = false;
const IMPORTANCE_SAMPLING = false;
const STACK_SIZE = 20;

@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var<storage, read> sphere_objs : array<Sphere>;
@group(0) @binding(2) var<storage, read> quad_objs : array<Quad>;
@group(0) @binding(3) var<storage, read_write> framebuffer : array<vec4f>;
@group(0) @binding(4) var<storage, read> triangles: array<Triangle>;
@group(0) @binding(5) var<storage, read> materials: array<Material>;
@group(0) @binding(6) var<storage, read> bvh: array<AABB>;

var<private> NUM_SPHERES : i32;
var<private> NUM_QUADS : i32;
var<private> NUM_AABB : i32;

var<private> rand_state : u32 = 0u;
var<private> pixel_coords : vec3f;

var<private> hit_rec : HitRecord;
var<private> scatter_rec : ScatterRecord;
var<private> lights : Quad;
var<private> ray_tmin : f32 = 0.000001;
var<private> ray_tmax : f32 = MAX_FLOAT;
var<private> stack : array<i32, STACK_SIZE>;

struct Uniforms {
  screen_dims: vec2f,
  frame_num: f32,
  reset_buffer: f32,
  view_matrix: mat4x4f,
}

struct Ray {
    origin: vec3f,
    dir: vec3f,
}

struct Material {
    color: vec3f,
    specular_color: vec3f,
     emission_color: vec3f,
     specular_strength: f32,
    roughness: f32,
    eta: f32,
    material_type: f32
}

struct ModelTransform {
    model_matrix: mat4x4f,
    inv_model_matrix: mat4x4f
}

struct Sphere {
    center: vec3f,
    r: f32,
    global_id: f32,
    local_id: f32,
    material_id: f32
}

struct Quad {
    Q: vec3f,
    u: vec3f,
    local_id: f32,
    v: vec3f,
    global_id: f32,
    normal: vec3f,
    D: f32,
    w: vec3f,
    material_id: f32
}

struct Triangle {
    A: vec3f,
    B: vec3f,
    C: vec3f,
    normalA: vec3f,
    normalB: vec3f,
    normalC: vec3f,
    mesh_id: f32,
}

struct AABB {
    min: vec3f,
    right_offset: f32,
    max: vec3f,

    prim_type: f32,
    prim_id: f32,
    prim_count: f32,
    skip_link: f32,
    axis: f32
}

struct HitRecord {
    p: vec3f,
    t: f32,
    normal: vec3f,
    front_face: bool,
    material: Material
}

struct ScatterRecord {
    pdf: f32,
    skip_pdf: bool,
    skip_pdf_ray: Ray,
}

fn get2Dfrom1D(pos: vec2f) -> u32 {
    return (u32(pos.y) * u32(uniforms.screen_dims.x) + u32(pos.x));
}

@fragment
fn fs(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {

    let i = get2Dfrom1D(fragCoord.xy);
    var color = framebuffer[i].xyz / uniforms.frame_num;

    color = aces_approx(color.xyz);
    color = pow(color.xyz, vec3f(1 / 2.2));

    if uniforms.reset_buffer == 1 {
        framebuffer[i] = vec4f(0);
    }

    return vec4f(color, 1);
}

/// Vertex paints a flat texture

struct Vertex {
	@location(0) position: vec2f,
};

@vertex
fn vs(
    vert: Vertex
) -> @builtin(position) vec4f {

    return vec4f(vert.position, 0.0, 1.0);
}