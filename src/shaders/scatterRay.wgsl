fn materialScatter(ray_in: Ray) -> Ray {
    var scattered = Ray(vec3<f32>(0), vec3<f32>(0));
    // do_specular = 0;
  // LAMBERTIAN
    let uvw = onbBuildFromW(hit_rec.normal);
    var diffuse_dir = cosineSamplingWrtZ();
    diffuse_dir = normalize(onbGetLocal(diffuse_dir));

    scattered = Ray(hit_rec.p, diffuse_dir);

    return scattered;
}

// Two helper functions to mimic the book
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