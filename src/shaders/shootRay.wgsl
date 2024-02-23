fn pathTrace() -> vec3f {
    var pix_color = vec3f(0, 0, 0);

    for (var i = 0; i < NUM_SAMPLES; i += 1) {
        let ray = getCameraRay(
            (uniforms.screen_dims.x / uniforms.screen_dims.y) * (2 * ((pixel_coords.x - 0.5 + rand2D()) / uniforms.screen_dims.x) - 1),
            -1 * (2 * ((pixel_coords.y - 0.5 + rand2D()) / uniforms.screen_dims.y) - 1)
        );

        pix_color += rayColor(ray);
    }

    pix_color /= NUM_SAMPLES;

    return pix_color;
}

fn getCameraRay(s: f32, t: f32) -> Ray {
    let dir = normalize(uniforms.view_matrix * vec4f(vec3f(s, t, -fov_factor), 0)).xyz;
    let ray = Ray(cam_origin, dir);

    return ray;
}
