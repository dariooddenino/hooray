fn materialScatter(ray_in: Ray) -> Ray {
    var scattered = Ray(vec3<f32>(0), vec3<f32>(0));
    do_specular = 0;
  // LAMBERTIAN
    let uvw = onbBuildFromW(hit_rec.normal);
    var diffuse_dir = cosineSamplingWrtZ();
    diffuse_dir = normalize(onbGetLocal(diffuse_dir));

    scattered = Ray(hit_rec.p, diffuse_dir);

    return scattered;
}