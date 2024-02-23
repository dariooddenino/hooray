fn rayColor(incident_ray: Ray) -> vec3f {
    var curr_ray = incident_ray;
    var acc_radiance = vec3f(0); // initial radiance (color) is black
    var throughput = vec3f(1); // initial throughput is 1 (no attenuation)

    for (var i = 0; i < MAX_BOUNCES; i++) {
        if hitScene(curr_ray) == false {
            let unit_direction = normalize(incident_ray.direction);
            let a = 0.5 * (unit_direction.y + 1);
            acc_radiance += (((1 - a) * vec3f(1, 1, 1) + a * vec3f(0.5, 0.7, 1)) * throughput);
            break;
        } else {
            acc_radiance += vec3f(0.1, 0, 0);
            // if ((pixel_coords.x + pixel_coords.y) % 2) < 1 {
            //     acc_radiance += (vec3f(0.0, 0.1, 0.0) * throughput);
            // } else {
            //     acc_radiance += (vec3f(0.0, 0.0, 0.1) * throughput);
            // }
        }
    }

    return acc_radiance;
}