@compute
@workgroup_size(64, 1, 1)
fn computeFrameBuffer(
    @builtin(workgroup_id) workgroup_id: vec3<u32>,
    @builtin(local_invocation_id) local_invocation_id: vec3<u32>,
    @builtin(local_invocation_index) local_invocation_index: u32,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
) {
    // NOTE I've commented everything else out, line 10 is enough to make the panic happen
    // let ray = Ray(vec3<f32>(0, 0, 0), vec3<f32>(0, 0, 0));
    let workgroup_index = workgroup_id.x + workgroup_id.y * num_workgroups.x + workgroup_id.z * num_workgroups.x * num_workgroups.y;
    let pixel_index = workgroup_index * 64 + local_invocation_index;		// global invocation index
    pixel_coords = vec3<f32>(f32(pixel_index) % uniforms.screen_dims.x, f32(pixel_index) / uniforms.screen_dims.x, 1);

    fov_factor = 1 / tan(60 * (PI / 180) / 2);
    cam_origin = uniforms.eye;

    NUM_SPHERES = i32(arrayLength(&sphere_objs));

    rand_state = pixel_index + u32(uniforms.frame_num) * 719393;

    // // get_lights();
    var path_traced_color = pathTrace();
    var frag_color = path_traced_color.xyz;

    // Progressive rendering with low samples
    if uniforms.reset_buffer == 0 {
        let weight = 1.0 / (uniforms.frame_num +1);
        frag_color = framebuffer[pixel_index].xyz * (1 - weight) + path_traced_color * weight;
    }

    framebuffer[pixel_index] = vec4<f32>(frag_color.xyz, 1);
}


// Paint a flat texture from the framebuffer

fn get1Dfrom2D(pos: vec2<f32>) -> u32 {
    return (u32(pos.y) * u32(uniforms.screen_dims.x) + u32(pos.x));
}

@fragment
fn fs(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {

    let i = get1Dfrom2D(fragCoord.xy);
    // This makes it fade to black.
    // var color = framebuffer[i].xyz / uniforms.frame_num;
    var color = framebuffer[i].xyz;

    color = acesApprox(color.xyz);
    color = pow(color.xyz, vec3<f32>(1 / 2.2));

    // This gives an unpleasant black flicker
    // if uniforms.reset_buffer == 1 {
    //     framebuffer[i] = vec4<f32>(0);
    // }

    return vec4<f32>(color, 1);
}


struct Vertex {
	@location(0) position: vec2<f32>,
};

@vertex
fn vs(
    vert: Vertex
) -> @builtin(position) vec4<f32> {

    return vec4<f32>(vert.position, 0.0, 1.0);
}
