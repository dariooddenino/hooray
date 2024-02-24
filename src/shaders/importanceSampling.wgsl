fn cosineSamplingWrtZ() -> vec3<f32> {
    let r1 = rand2D();
    let r2 = rand2D();

    let phi = 2 * PI * r1;
    let x = cos(phi) * sqrt(r2);
    let y = sin(phi) * sqrt(r2);
    let z = sqrt(1 - r2);

    return vec3<f32>(x, y, z);
}


// creates an orthonormal basis 
fn onbBuildFromW(w: vec3<f32>) -> mat3x3<f32> {
    unit_w = normalize(w);
    let a = select(vec3<f32>(1, 0, 0), vec3<f32>(0, 1, 0), abs(unit_w.x) > 0.9);
    v = normalize(cross(unit_w, a));
    u = cross(unit_w, v);
    return mat3x3<f32>(u, v, unit_w);
}

fn onbGetLocal(a: vec3<f32>) -> vec3<f32> {
    return u * a.x + v * a.y + unit_w * a.z;
}