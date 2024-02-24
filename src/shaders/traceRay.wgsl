fn rayColor(incident_ray: Ray) -> vec3<f32> {
    var curr_ray = incident_ray;
    var acc_radiance = vec3<f32>(0); // initial radiance (color) is black
    var throughput = vec3<f32>(1); // initial throughput is 1 (no attenuation)

    for (var i = 0; i < MAX_BOUNCES; i++) {
        if !hitScene(curr_ray) {
            let unit_direction = normalize(incident_ray.direction);
            let a = 0.5 * (unit_direction.y + 1);
            acc_radiance += (((1 - a) * vec3<f32>(0.8, 0.8, 0.8) + a * vec3<f32>(0.1, 0.2, 0.5)) * throughput);
            break;
        } else {
            // acc_radiance += 0.5 * (hit_rec.normal + 1) * throughput;
            // acc_radiance += vec3<f32>(0.1, 0, 0);
            // if ((pixel_coords.x + pixel_coords.y) % 2) < 1 {
            //     acc_radiance += (vec3<f32>(0.0, 0.1, 0.0) * throughput);
            // } else {
            //     acc_radiance += (vec3<f32>(0.0, 0.0, 0.1) * throughput);
            // }
            let scattered = materialScatter(curr_ray);
            acc_radiance += vec3<f32>(0.3, 0.5, 0.2) * throughput;
            throughput *= mix(vec3<f32>(0.3, 0.5, 0.2), vec3<f32>(0, 0, 0), do_specular);
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

    return acc_radiance;
}
