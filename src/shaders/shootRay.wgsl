fn pathTrace() -> vec3<f32> {
    var pix_color = vec3<f32>(0, 0, 0);

    for (var i = 0; i < uniforms.sample_rate; i += 1) {
        let ray = getCameraRay();

        pix_color += rayColor(ray);
    }

    pix_color = pix_color / f32(uniforms.sample_rate);

    return pix_color;
}

fn getCameraRay() -> Ray {
    // TODO hardcoding for now ~ NOT working
    let up = vec3<f32>(0, 1, 0);
    let look_at = vec3<f32>(0, 0, 0);
    //
    // let focus_dist: f32 = 5; // uniforms.focus_dist;
    let focus_dist: f32 = length(cam_origin - look_at);
    let defocus_angle: f32 = uniforms.defocus_angle;
    // vertical fov
    const theta: f32 = radians(40);
    const h = tan(theta / 2);
    let viewport_height = 2.0 * h * focus_dist;
    let viewport_width = viewport_height * f32(uniforms.screen_dims.x) / f32(uniforms.screen_dims.y);

    let u = vec3<f32>(uniforms.view_matrix[0][0], uniforms.view_matrix[1][0], uniforms.view_matrix[2][0]);
    let v = vec3<f32>(uniforms.view_matrix[0][1], uniforms.view_matrix[1][1], uniforms.view_matrix[2][1]);
    let w = vec3<f32>(uniforms.view_matrix[0][2], uniforms.view_matrix[1][2], uniforms.view_matrix[2][2]);

    let viewport_u = vec3<f32>(viewport_width) * u;
    let viewport_v = vec3<f32>(viewport_height) * v * vec3<f32>(-1);

    let pixel_delta_u = viewport_u / f32(uniforms.screen_dims.x);
    let pixel_delta_v = viewport_v / f32(uniforms.screen_dims.y);

    let w_focus_dist = vec3<f32>(focus_dist) * w;

    let viewport_upper_left = cam_origin - w_focus_dist - viewport_u / 2 - viewport_v / 2;
    let pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

    // Get a randomly-sampled camera ray for the pixel at location i,j, originating from
    // the camera defocus disk.

    let defocus_radius = focus_dist * tan(radians(defocus_angle / 2));
    let defocus_disk_u = u * vec3<f32>(defocus_radius);
    let defocus_disk_v = v * vec3<f32>(defocus_radius);

    let pixel_center = pixel00_loc + (pixel_coords.x * pixel_delta_u) + (pixel_coords.y * pixel_delta_v);
    let pixel_sample = pixel_center + pixelSampleSquare(pixel_delta_u, pixel_delta_v);

    var ray_origin = cam_origin;
    if (defocus_angle > 0) {
        ray_origin = defocusDiskSample(cam_origin, defocus_disk_u, defocus_disk_v);
    }
    let ray_direction = normalize(pixel_sample - ray_origin);
    // return Ray(ray_origin, ray_direction);

    // test
    let s = (f32(uniforms.screen_dims.x) / f32(uniforms.screen_dims.y)) * (2 * (pixel_coords.x - 0.5 * rand2D()) / f32(uniforms.screen_dims.x)) - 1;
    let t = - 1 * (2 * ((pixel_coords.y - 0.5 + rand2D()) / f32(uniforms.screen_dims.y)) - 1);

    let fov_factor: f32 = 40;
    let dir = normalize(uniforms.view_matrix * vec4<f32>(vec3<f32>(s, t, -fov_factor), 0)).xyz;
    return Ray(ray_origin, dir);
}

// Antialiasing
// Retruns a random point in the square surrounding a pixel at the origin
fn pixelSampleSquare(pixel_delta_u: vec3<f32>, pixel_delta_v: vec3<f32>) -> vec3<f32> {
    let px = -0.5 + rand2D();
    let py = -0.5 + rand2D();
    return (px * pixel_delta_u) + (py * pixel_delta_v);
}

