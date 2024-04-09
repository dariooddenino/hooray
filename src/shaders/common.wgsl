// TEMP sysgpu functions

fn sys_cross(a: vec3<f32>, b: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
}

fn sys_reflect(v: vec3<f32>, n: vec3<f32>) -> vec3<f32> {
    return v - 2 * dot(v, n) * n;
}

fn sys_refract(v: vec3<f32>, n: vec3<f32>, eta: f32) -> vec3<f32> {
    let cos_theta = dot(v, n);
    let sin_theta = sqrt(1 - cos_theta * cos_theta);
    let sin_theta_eta = eta * sin_theta;
    let cos_theta_eta = eta * cos_theta;
    return v * (cos_theta * (1 - eta) + sin_theta_eta) - n * sin_theta_eta;
}

// END TMP

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

fn near_zero(v : vec3<f32>) -> bool {
	return (abs(v[0]) < 0 && abs(v[1]) < 0 && abs(v[2]) < 0);
}

fn randomVec() -> vec3<f32> {
    return vec3<f32>(rand2D(), rand2D(), rand2D());
}

fn randomVecRange(min: f32, max: f32) -> vec3<f32> {
    return vec3<f32>(randomDouble(min, max), randomDouble(min, max), randomDouble(min, max));
}

// ACES approximation for tone mapping
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/):
fn acesApprox(v: vec3<f32>) -> vec3<f32> {
    let v1 = v * 0.6f;
    const a = 2.51f;
    const b = 0.03f;
    const c = 2.43f;
    const d = 0.59f;
    const e = 0.14f;
    return clamp((v1 * (a * v1 + b)) / (v1 * (c * v1 + d) + e), vec3(0.0f), vec3(1.0f));
}
