@compute
@workgroup_size(64, 1, 1)fn computeFrameBuffer(
    @builtin(workgroup_id) workgroup_id: vec3<u32>,
    @builtin(local_invocation_id) local_invocation_id: vec3<u32>,
    @builtin(local_invocation_index) local_invocation_index: u32,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
) {
    let workgroup_index = workgroup_id.x + workgroup_id.y * num_workgroups.x + workgroup_id.z * num_workgroups.x * num_workgroups.y;
    let pixel_index = workgroup_index * 64 + local_invocation_index;		// global invocation index
    let coords = vec3f(f32(pixel_index) % uniforms.screen_dims.x, f32(pixel_index) / uniforms.screen_dims.x, 1);

    // For now...
    cam_origin = (uniforms.view_matrix * vec4f(0, 0, 0, 1)).xyz;

    var path_traced_color = pathTrace();
    var frag_color = path_traced_color.xyz;

    framebuffer[pixel_index] = vec4f(frag_color.xyz, 1);
}


// Paint a flat texture from the framebuffer

fn get1Dfrom2D(pos: vec2f) -> u32 {
    return (u32(pos.y) * u32(uniforms.screen_dims.x) + u32(pos.x));
}

@fragment
fn fs(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {

    let i = get1Dfrom2D(fragCoord.xy);
    var color = framebuffer[i].xyz; // / uniforms.frame_num;

    // color = aces_approx(color.xyz);
    // color = pow(color.xyz, vec3f(1 / 2.2));

    if uniforms.reset_buffer == 1 {
        framebuffer[i] = vec4f(0);
    }

    return vec4f(color, 1);
}


struct Vertex {
	@location(0) position: vec2f,
};

@vertex
fn vs(
    vert: Vertex
) -> @builtin(position) vec4f {

    return vec4f(vert.position, 0.0, 1.0);
}
