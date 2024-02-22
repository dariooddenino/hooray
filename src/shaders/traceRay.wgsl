fn rayColor(incident_ray: Ray) -> vec3f {
    var curr_ray = incident_ray;
    var acc_radiance = vec3f(0); // initial radiance (color) is black
    var throughput = vec3f(1); // initial throughput is 1 (no attenuation)
    let background_color = vec3f(0.8, 0.8, 1.0); // light blue

    for (var i = 0; i < MAX_BOUNCES; i++) {
        acc_radiance += (background_color * throughput);
    break;
    }

    return acc_radiance;
}