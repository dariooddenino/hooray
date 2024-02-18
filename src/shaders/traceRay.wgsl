fn ray_color(incident_ray: Ray) -> vec3f {

    var curr_ray = incident_ray;
    var acc_radiance = vec3f(0);	// initial radiance (pixel color) is black
    var throughput = vec3f(1);		// initial throughput is 1 (no attenuation)
    let background_color = vec3f(0, 1, 1);

    for (var i = 0; i < MAX_BOUNCES; i++) {
        if hitScene(curr_ray) == false {
            acc_radiance += (background_color * throughput);
			break;
        }

		// unidirectional light
        var emission_color = hitRec.material.emission_color;
        if !hit_rec.front_face {
            emission_color = vec3f(0);
        }

        if IMPORTANCE_SAMPLING {
			// IMPORTANCE SAMPLING TOWARDS LIGHT
			// diffuse scatter ray
            let scatterred_surface = material_scatter(curr_ray);

            if scatter_rec.skip_pdf {
                acc_radiance += emission_color * throughput;
                throughput *= mix(hitRec.material.color, hitRec.material.specular_color, do_specular);

                curr_ray = scatter_rec.skip_pdf_ray;
				continue;
            }

			// ray sampled towards light
            let scattered_light = get_random_on_quad(lights, hit_rec.p);

            var scattered = scattered_light;
            var rand = rand2D();
            if rand > 0.2 {
                scattered = scatterred_surface;
            }

            let lambertian_pdf = onb_lambertian_scattering_pdf(scattered);
            let light_pdf = light_pdf(scattered, lights);
            let pdf = 0.2 * light_pdf + 0.8 * lambertian_pdf;

            if pdf <= 0.00001 {
                return emission_color * throughput;
            }

            acc_radiance += emission_color * throughput;
            throughput *= ((lambertian_pdf * mix(hit_rec.material.color, hit_rec.material.specular_color, do_specular)) / pdf);
            curr_ray = scattered;
        } else {
            let scattered = material_scatter(curr_ray);

            acc_radiance += emission_color * throughput;
            throughput *= mix(hit_rec.material.color, hit_rec.material.specular_color, do_specular);

            currRay = scattered;
        }

		// russian roulette
        if i > 2 {
            let p = max(throughput.x, max(throughput.y, throughput.z));
            if rand2D() > p {
				break;
            }

            throughput *= (1.0 / p);
        }
    }

    return acc_radiance;
}