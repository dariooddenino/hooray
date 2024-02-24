fn pathTrace() -> vec3<f32> {
    var pix_color = vec3<f32>(0, 0, 0);

    for (var i = 0; i < NUM_SAMPLES; i += 1) {
        let ray = getCameraRay(
            (uniforms.screen_dims.x / uniforms.screen_dims.y) * (2 * ((pixel_coords.x - 0.5 + rand2D()) / uniforms.screen_dims.x) - 1),
            -1 * (2 * ((pixel_coords.y - 0.5 + rand2D()) / uniforms.screen_dims.y) - 1)
        );
        // let ray = getCameraRayOld();

        pix_color += rayColor(ray);
    }

    pix_color = pix_color / NUM_SAMPLES;

    return pix_color;
}

// fn getCameraRayOld() -> Ray {
//     let focal_length: f32 = 1;
//     let cam_cen = vec3<f32>(0, 0, 0);
//     let viewport_u = vec3<f32>(uniforms.screen_dims.x, 0, 0);
//     let viewport_v = vec3<f32>(0, -uniforms.screen_dims.y, 0);
//     let pixel_delta_u = viewport_u / uniforms.screen_dims.x;
//     let pixel_delta_v = viewport_v / uniforms.screen_dims.y;
//     let viewport_upper_left = cam_cen - vec3<f32>(0, 0, focal_length) - viewport_u / 2 - viewport_v / 2;
//     let pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);
//     let pixel_center = pixel00_loc + (pixel_coords.x * pixel_delta_u) + (pixel_coords.y * pixel_delta_v);
//     let ray_direction = pixel_center - cam_cen;
//     let ray = Ray(cam_cen, ray_direction);
//     return ray;
// }

fn getCameraRay(s: f32, t: f32) -> Ray {
    let dir = normalize(uniforms.view_matrix * vec4<f32>(vec3<f32>(s, t, -fov_factor), 0)).xyz;
    let ray = Ray(cam_origin, dir);

    return ray;
}
