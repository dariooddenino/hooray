fn reflectance(cosine : f32, ref_idx : f32) -> f32 {
	var r0 = (1 - ref_idx) / (1 + ref_idx);
	r0 = r0 * r0;
	return r0 + (1 - r0) * pow((1 - cosine), 5);
}

fn uniformRandomInUnitSphere() -> vec3<f32> {
    let phi = rand2D() * 2.0 * PI;
    let theta = acos(2.0 * rand2D() - 1.0);

    let x = sin(theta) * cos(phi);
    let y = sin(theta) * sin(phi);
    let z = cos(theta);

    return normalize(vec3<f32>(x, y, z));
}

fn randomInUnitDisk() -> vec3<f32> {
    let theta = 2 * PI * rand2D();
    let r = sqrt(rand2D());
    return normalize(vec3<f32>(r * cos(theta), r * sin(theta), 0));
}

fn randomInUnitSphere() -> vec3<f32> {
    let phi = rand2D() * 2.0 * PI;
    let theta = acos(2.0 * rand2D() - 1.0);

    let x = sin(theta) * cos(phi);
    let y = sin(theta) * sin(phi);
    let z = cos(theta);

    return normalize(vec3<f32>(x, y, z));
}

fn randomOnHemisphere(normal: vec3<f32>) -> vec3<f32> {
    let on_unit_sphere = randomInUnitSphere();
    if dot(on_unit_sphere, normal) > 0.0 {
        return on_unit_sphere;
    } else {
        return -on_unit_sphere;
    }
}

fn randomUnitVector() -> vec3<f32> {
    let p = randomInUnitSphere();

    return p / vec3<f32>(length(p));
}

fn defocusDiskSample(center: vec3<f32>, defocus_disk_u: vec3<f32>, defocus_disk_v: vec3<f32>) -> vec3<f32> {
    // Returns a random point in the camera defocus disk.
    let p = randomInUnitDisk();
    return center + (p.x * defocus_disk_u) + (p.y * defocus_disk_v);
}

fn uniformSamplingHemisphere() -> vec3<f32> {
    let on_unit_sphere = uniformRandomInUnitSphere();
    let sign_dot = select(1.0, 0.0, dot(on_unit_sphere, hit_rec.normal) > 0.0);
    return normalize(mix(on_unit_sphere, -on_unit_sphere, sign_dot));
}

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