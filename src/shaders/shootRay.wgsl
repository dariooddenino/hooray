fn pathTrace() -> vec3<f32> {
    var pix_color = vec3<f32>(0, 0, 0);

    for (var i = 0; i < MAX_SAMPLES; i += 1) {
        // let ray = getCameraRay(
        //     (uniforms.screen_dims.x / uniforms.screen_dims.y) * (2 * ((pixel_coords.x - 0.5 + rand2D()) / uniforms.screen_dims.x) - 1),
        //     -1 * (2 * ((pixel_coords.y - 0.5 + rand2D()) / uniforms.screen_dims.y) - 1)
        // );
        let ray = getCameraRay();

        pix_color += rayColor(ray);
    }

    pix_color = pix_color / MAX_SAMPLES;

    return pix_color;
}

fn getCameraRay() -> Ray {
    let focal_length = 1.0;
    let viewport_height = 2.0;
    let viewport_width = viewport_height * uniforms.screen_dims.x / uniforms.screen_dims.y;

    let viewport_u = vec3<f32>(viewport_width, 0, 0);
    let viewport_v = vec3<f32>(0, -viewport_height, 0);

    let pixel_delta_u = viewport_u / uniforms.screen_dims.x;
    let pixel_delta_v = viewport_v / uniforms.screen_dims.y;
    let viewport_upper_left = cam_origin - vec3<f32>(0, 0, focal_length) - viewport_u / 2 - viewport_v / 2;
    let pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);
    let pixel_center = pixel00_loc + (pixel_coords.x * pixel_delta_u) + (pixel_coords.y * pixel_delta_v);
    let ray_direction = pixel_center - cam_origin;
    return Ray(cam_origin, ray_direction);
}

// fn getCameraRay(s: f32, t: f32) -> Ray {
//     let dir = normalize(uniforms.view_matrix * vec4<f32>(vec3<f32>(s, t, -fov_factor), 0)).xyz;
//     let ray = Ray(cam_origin, dir);

//     return ray;
// }
