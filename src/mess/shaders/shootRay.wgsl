fn pathTrace() -> vec3f {

    var pix_color = vec3f(0, 0, 0);

    if STRATIFY {
        let sqrt_spp = sqrt(NUM_SAMPLES);
        let recip_sqrt_spp = 1.0 / f32(i32(sqrt_spp));
        var num_samples = 0.0;	// NUM_SAMPLES may not be perfect square

        for (var i = 0.0; i < sqrt_spp; i += 1.0) {
            for (var j = 0.0; j < sqrt_spp; j += 1.0) {
                let ray = getCameraRay(
                    (uniforms.screen_dims.x / uniforms.screen_dims.y) * (2 * ((pixel_coords.x - 0.5 + (recip_sqrt_spp * (i + rand2D()))) / uniforms.screen_dims.x) - 1),
                    -1 * (2 * ((pixel_coords.y - 0.5 + (recip_sqrt_spp * (j + rand2D()))) / uniforms.screen_dims.y) - 1)
                );

                pix_color += ray_color(ray);

                num_samples += 1;
            }
        }

        pix_color /= num_samples;
    } else {
        for (var i = 0; i < NUM_SAMPLES; i += 1) {
            let ray = getCameraRay(
                (uniforms.screen_dims.x / uniforms.screen_dims.y) * (2 * ((pixel_coords.x - 0.5 + rand2D()) / uniforms.screen_dims.x) - 1),
                -1 * (2 * ((pixel_coords.y - 0.5 + rand2D()) / uniforms.screen_dims.y) - 1)
            );

            pix_color += ray_color(ray);
        }

        pix_color /= NUM_SAMPLES;
    }

    return pix_color;
}

var<private> fov_factor : f32;
var<private> cam_origin: vec3f;

fn getCameraRay(s: f32, t: f32) -> Ray {

    let dir = normalize(uniforms.view_matrix * vec4f(vec3f(s, t, -fov_factor), 0)).xyz;
    var ray = Ray(cam_origin, dir);

    return ray;
}