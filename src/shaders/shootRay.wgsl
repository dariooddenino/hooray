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
    // TODO hardcoding for now ~ NOT working
    let up = vec3<f32>(0, 1, 0);
    let look_at = vec3<f32>(0, 0, 0);
    let focal_length = length(cam_origin - look_at);
    // vertical fov
    const theta: f32 = PI / 2;
    const h = tan(theta / 2);
    let viewport_height = 2.0 * h * focal_length;
    let viewport_width = viewport_height * uniforms.screen_dims.x / uniforms.screen_dims.y;

    let u = vec3<f32>(uniforms.view_matrix[0][0], uniforms.view_matrix[1][0], uniforms.view_matrix[2][0]);
    let v = vec3<f32>(uniforms.view_matrix[0][1], uniforms.view_matrix[1][1], uniforms.view_matrix[2][1]);
    let w = -vec3<f32>(uniforms.view_matrix[0][2], uniforms.view_matrix[1][2], uniforms.view_matrix[2][2]);

    let viewport_u = vec3<f32>(viewport_width) * u;
    let viewport_v = vec3<f32>(viewport_height) * v;

    let pixel_delta_u = viewport_u / uniforms.screen_dims.x;
    let pixel_delta_v = viewport_v / uniforms.screen_dims.y;

    let w_focal_length = vec3<f32>(focal_length) * w;

    let viewport_upper_left = cam_origin - w_focal_length - viewport_u / 2 - viewport_v / 2;
    let pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);
    let pixel_center = pixel00_loc + (pixel_coords.x * pixel_delta_u) + (pixel_coords.y * pixel_delta_v);
    let pixel_sample = pixel_center + pixelSampleSquare(pixel_delta_u, pixel_delta_v);
    let ray_direction = -(pixel_center - cam_origin);
    return Ray(cam_origin, ray_direction);
}

// Antialiasing
// Retruns a random point in the square surrounding a pixel at the origin
fn pixelSampleSquare(pixel_delta_u: vec3<f32>, pixel_delta_v: vec3<f32>) -> vec3<f32> {
    let px = -0.5 + rand2D();
    let py = -0.5 + rand2D();
    return (px * pixel_delta_u) + (py * pixel_delta_v);
}

