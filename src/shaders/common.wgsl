fn at(ray: Ray, t: f32) -> vec3<f32> {
    return ray.origin + t * ray.direction;
}

// PCG prng
// https://www.shadertoy.com/view/XlGcRh
fn rand2D() -> f32 {
    rand_state = rand_state * 747796405u + 2891336453u;
    var word: u32 = ((rand_state >> ((rand_state >> 28u) + 4u)) ^ rand_state) * 277803737u;
    return f32((word >> 22u) ^ word) / 4294967295;
}

fn randomDouble(min: f32, max: f32) -> f32 {
    return min + (max - min) * rand2D();
}

// ACES approximation for tone mapping
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/):
fn aces_approx(v: vec3<f32>) -> vec3<f32> {
    let v1 = v * 0.6f;
    const a = 2.51f;
    const b = 0.03f;
    const c = 2.43f;
    const d = 0.59f;
    const e = 0.14f;
    return clamp((v1 * (a * v1 + b)) / (v1 * (c * v1 + d) + e), vec3(0.0f), vec3(1.0f));
}