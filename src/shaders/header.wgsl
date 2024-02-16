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
// TODO: this was actually 3
@group(0) @binding(1) var<storage, read_write> framebuffer : array<vec4f>;

struct Uniforms {
  screenDims: vec2f,
  frameNum: f32,
  resetBuffer: f32,
  viewMatrix: mat4x4f,
}

fn get2Dfrom1D(pos: vec2f) -> u32 {
    return (u32(pos.y) * u32(uniforms.screenDims.x) + u32(pos.x));
}

@fragment
fn fs(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {

    let i = get2Dfrom1D(fragCoord.xy);
    var color = framebuffer[i].xyz / uniforms.frameNum;

    color = aces_approx(color.xyz);
    color = pow(color.xyz, vec3f(1 / 2.2));

    if uniforms.resetBuffer == 1 {
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