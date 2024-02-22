var<private> do_specular : f32;
fn material_scatter(ray_in: Ray) -> Ray {

    var scattered = Ray(vec3f(0), vec3f(0));
    do_specular = 0;
    if hit_rec.material.material_type == LAMBERTIAN {

        let uvw = onb_build_from_w(hit_rec.normal);
        var diffuse_dir = cosine_sampling_wrt_Z();
        diffuse_dir = normalize(onb_get_local(diffuse_dir));

        scattered = Ray(hit_rec.p, diffuse_dir);

        do_specular = select(0.0, 1.0, rand2D() < hit_rec.material.specular_strength);

		// var diffuse_dir = uniform_sampling_hemisphere();
		// var diffuse_dir = cosine_sampling_hemisphere();
		// if(near_zero(diffuse_dir)) {
		// 	diffuse_dir = hit_rec.normal;
		// }

		// scattered = Ray(hit_rec.p, normalize(diffuse_dir));
        var specular_dir = reflect(ray_in.dir, hit_rec.normal);
        specular_dir = normalize(mix(specular_dir, diffuse_dir, hit_rec.material.roughness));

        scattered = Ray(hit_rec.p, normalize(mix(diffuse_dir, specular_dir, do_specular)));

        scatter_rec.skip_pdf = false;

        if do_specular == 1.0 {
            scatter_rec.skip_pdf = true;
            scatter_rec.skip_pdf_ray = scattered;
        }
    } else if hit_rec.material.material_type == MIRROR {
        var reflected = reflect(ray_in.dir, hit_rec.normal);
        scattered = Ray(hit_rec.p, normalize(reflected + hit_rec.material.roughness * uniform_random_in_unit_sphere()));

        scatter_rec.skip_pdf = true;
        scatter_rec.skip_pdf_ray = scattered;
    } else if hit_rec.material.material_type == GLASS {
        var ir = hit_rec.material.eta;
        if hit_rec.front_face == true {
            ir = (1.0 / ir);
        }

        let unit_direction = normalize(ray_in.dir);
        let cos_theta = min(dot(-unit_direction, hit_rec.normal), 1.0);
        let sin_theta = sqrt(1 - cos_theta * cos_theta);

        var direction = vec3f(0);
        if ir * sin_theta > 1.0 || reflectance(cos_theta, ir) > rand2D() {
		// if(ir * sin_theta > 1.0) {
            direction = reflect(unit_direction, hit_rec.normal);
        } else {
            direction = refract(unit_direction, hit_rec.normal, ir);
        }

        if near_zero(direction) {
            direction = hit_rec.normal;
        }

        scattered = Ray(hit_rec.p, normalize(direction));

        scatter_rec.skip_pdf = true;
        scatter_rec.skip_pdf_ray = scattered;
    } else if hit_rec.material.material_type == ISOTROPIC {
		// scattered = Ray(hit_rec.p, uniform_random_in_unit_sphere());
		// scatter_rec.skip_pdf = true;
		// scatter_rec.skip_pdf_ray = scattered;

        let g = hit_rec.material.specular_strength;
		// let cos_hg = (1 - g*g) / (4 * PI * pow(1 + g*g - 2*g*cos(2 * PI * rand2D()), 3/2));
        let cos_hg = (1 + g * g - pow(((1 - g * g) / (1 - g + 2 * g * rand2D())), 2)) / (2 * g);
        let sin_hg = sqrt(1 - cos_hg * cos_hg);
        let phi = 2 * PI * rand2D();

        let hg_dir = vec3f(sin_hg * cos(phi), sin_hg * sin(phi), cos_hg);

        let uvw = onb_build_from_w(ray_in.dir);
        scattered = Ray(hit_rec.p, normalize(onb_get_local(hg_dir)));

		// scatter_rec.pdf = (1 - g*g) / (4 * PI * pow(1 + g*g - 2*g*cos(2 * PI * rand2D()), 3/2));
        scatter_rec.skip_pdf = true;
        scatter_rec.skip_pdf_ray = scattered;
    }

    return scattered;
}