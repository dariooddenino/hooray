fn materialScatter(ray_in: Ray) -> Ray {
    var scattered = Ray(vec3<f32>(0), vec3<f32>(0));
    do_specular = 0;
    if (hit_rec.material.material_type == LAMBERTIAN) {
        let uvw = onbBuildFromW(hit_rec.normal);
        var diffuse_dir = cosineSamplingWrtZ();
        diffuse_dir = normalize(onbGetLocal(diffuse_dir));

        do_specular = select(0.0, 1.0, rand2D() < hit_rec.material.specular_strength);

        var specular_dir = reflect(ray_in.direction, hit_rec.normal);
        specular_dir = normalize(mix(specular_dir, diffuse_dir, hit_rec.material.roughness));

        scattered = Ray(hit_rec.p, normalize(mix(diffuse_dir, specular_dir, do_specular)));

        scatter_rec.skip_pdf = false;

        if (do_specular == 1.0) {
            scatter_rec.skip_pdf = true;
            scatter_rec.skip_pdf_ray = scattered;
        }
    }

    else if (hit_rec.material.material_type == DIELECTRIC) {
        var ir = hit_rec.material.eta;
        if(hit_rec.front_face) {
            ir = (1.0 / ir);
        }

        let unit_direction = normalize(ray_in.direction);
        let cos_theta = min(dot(-unit_direction, hit_rec.normal), 1.0);
        let sin_theta = sqrt(1 - cos_theta * cos_theta);

        var direction = vec3<f32>(0);
        if(ir * sin_theta > 1.0 || reflectance(cos_theta, ir) > rand2D()) {
            direction = reflect(unit_direction, hit_rec.normal);
        } else {
            direction = refract(unit_direction, hit_rec.normal, ir);
        }

        if(near_zero(direction)) {
            direction = hit_rec.normal;
        }

        scattered = Ray(hit_rec.p, normalize(direction));

        scatter_rec.skip_pdf = true;
        scatter_rec.skip_pdf_ray = scattered;
    }

    else if (hit_rec.material.material_type == ISOTROPIC) {
		let g = hit_rec.material.specular_strength;
		let cos_hg = (1 + g*g - pow(((1 - g*g) / (1 - g + 2*g*rand2D())), 2)) / (2 * g);
		let sin_hg = sqrt(1 - cos_hg * cos_hg);
		let phi = 2 * PI * rand2D();

		let hg_dir = vec3f(sin_hg * cos(phi), sin_hg * sin(phi), cos_hg);

		let uvw = onbBuildFromW(ray_in.direction);
		scattered = Ray(hit_rec.p, normalize(onbGetLocal(hg_dir)));

		scatter_rec.skip_pdf = true;
		scatter_rec.skip_pdf_ray = scattered;
    }

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