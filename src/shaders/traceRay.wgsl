fn rayColor(incident_ray: Ray) -> vec3<f32> {
    var curr_ray = incident_ray;
    // Current ray color
    var color = vec3<f32>(0); // initial radiance (color) is black
    // Attenuation at each bounce
    var throughput = vec3<f32>(1);

    var bbox_color = vec3<f32>(1, 1, 1);

    var max_bounces = uniforms.max_bounces;
    // Reduce max bounces while moving.
    // It doesn't look very effective, I need more complex scenes.
    if (uniforms.frame_num < 15) {
        max_bounces /= 2;
    }


    for (var i = 0; i < max_bounces; i++) {
        if !hitScene(curr_ray) {
            let unit_direction = normalize(incident_ray.direction);
            let a = 0.5 * (unit_direction.y + 1);
            // Show hit boxes
            // bbox_color = vec3<f32>(1 - (f32(hit_rec.hit_bboxes) / 5), 1, 1 - (f32(hit_rec.hit_bboxes) / 5));
            // color += (((1 - a) * vec3<f32>(0.8, 0.8, 0.8) + a * vec3<f32>(0.1, 0.2, 0.5)) * throughput * bbox_color);
            color += vec3<f32>(0) * throughput * bbox_color;
            break;
        } else {

            // unidirectional light
            var emission_color = hit_rec.material.emission_color;
            if !hit_rec.front_face {
                emission_color = vec3<f32>(0);
            }

            // if IMPORTANCE_SAMPLING {

            // else {

            let scattered = materialScatter(curr_ray);
            // Show hit boxes
            // bbox_color = vec3<f32>(1 - (f32(hit_rec.hit_bboxes) / 20), 1, 1 - (f32(hit_rec.hit_bboxes) / 20));
            color += emission_color * throughput * bbox_color;
            throughput *= mix(hit_rec.material.color, hit_rec.material.specular_color, do_specular);
            curr_ray = scattered;
        }

        // russian roulette
        if i > 2 {
            let p = max(throughput.x, max(throughput.y, throughput.z));
            if rand2D() > p {
                break;
            }
            throughput = throughput * (1.0 / p);
        }
    }

    return color;
}
