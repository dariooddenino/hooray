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
    // let up = (uniforms.view_matrix * vec4<f32>(0, 1, 0, 0)).xyz;
    let up = vec3<f32>(0, 1, 0);
    let look_at = vec3<f32>(0, 0, 0);
    // let look_at = (uniforms.view_matrix * vec4<f32>(0, 0, 1, 0)).xyz;
    let focal_length = length(cam_origin - look_at);
    // vertical fov
    const theta: f32 = PI / 2;
    const h = tan(theta / 2);
    let viewport_height = 2.0 * h * focal_length;
    let viewport_width = viewport_height * uniforms.screen_dims.x / uniforms.screen_dims.y;

    // Calculate the u,v,w vectors for the camera coordinate frame.
    // Not working
    // let w = (uniforms.view_matrix * vec4<f32>(1, 0, 0, 0)).xyz;
    // let v = (uniforms.view_matrix * vec4<f32>(0, 1, 0, 0)).xyz;
    // let u = (uniforms.view_matrix * vec4<f32>(0, 0, 1, 0)).xyz;
    let w = -normalize(cam_origin - look_at);
    let u = normalize(cross(up, w));
    let v = cross(w, u);

    let viewport_u = vec3<f32>(viewport_width) * u;
    let viewport_v = vec3<f32>(viewport_height) * v;

    let pixel_delta_u = viewport_u / uniforms.screen_dims.x;
    let pixel_delta_v = viewport_v / uniforms.screen_dims.y;

    let w_focal_length = vec3<f32>(focal_length) * w;

    let viewport_upper_left = cam_origin - w_focal_length - viewport_u / 2 - viewport_v / 2;
    let pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);
    let pixel_center = pixel00_loc + (pixel_coords.x * pixel_delta_u) + (pixel_coords.y * pixel_delta_v);
    let ray_direction = -(pixel_center - cam_origin);
    return Ray(cam_origin, ray_direction);
}
// w = unit_vector(lookfrom - lookat);
//         u = unit_vector(cross(vup, w));
//         v = cross(w, u);

// zaxis = w
// xaxis = u
// yaxis = v

// ux vx wx
// uy vy wy
// uz vz wz
// origin

// fn getCameraRay(s: f32, t: f32) -> Ray {
//     let dir = normalize(uniforms.view_matrix * vec4<f32>(vec3<f32>(s, t, -fov_factor), 0)).xyz;
//     let ray = Ray(cam_origin, dir);

//     return ray;
// }
