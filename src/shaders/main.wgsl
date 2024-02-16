@compute
@workgroup_size(64, 1, 1)fn computeFrameBuffer(
    @builtin(workgroup_id) workgroup_id: vec3<u32>,
    @builtin(local_invocation_id) local_invocation_id: vec3<u32>,
    @builtin(local_invocation_index) local_invocation_index: u32,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
) {
    let workgroup_index = workgroup_id.x + workgroup_id.y * num_workgroups.x + workgroup_id.z * num_workgroups.x * num_workgroups.y;
    let pixel_index = workgroup_index * 64 + local_invocation_index;		// global invocation index
    pixel_coords = vec3f(f32(pixel_index) % uniforms.screen_dims.x, f32(pixel_index) / uniforms.screen_dims.x, 1);

    fov_factor = 1 / tan(60 * (PI / 180) / 2);
    cam_origin = (uniforms.view_matrix * vec4f(0, 0, 0, 1)).xyz;

    rand_state = pixel_index + u32(uniforms.frame_num) * 719393;
}