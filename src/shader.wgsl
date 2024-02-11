@vertex fn vs(
    @builtin(vertex_index) vertexIndex : u32
) -> @builtin(position) vec4f {
    let pos = array(
        vec2f(0, 0.5),
        vec2f(-0.5, -0.5),
        vec2f(0.5, -0.5)
    );

    return vec4f(pos[vertexIndex], 0, 1);
}

@fragment fn fs() -> @location(0) vec4f {
    return vec4f(1, 0, 0, 1);
}

@group(0) @binding(0) var<storage, read_write> workgroupResult: array<vec3u>;
@group(0) @binding(1) var<storage, read_write> localResult: array<vec3u>;
@group(0) @binding(2) var<storage, read_write> globalResult: array<vec3u>;

@compute @workgroup_size(2, 3, 4) fn computeSomething(
    @builtin(workgroup_id) workgroup_id: vec3<u32>,
    @builtin(local_invocation_id) local_invocation_id: vec3<u32>,
    @builtin(global_invocation_id) global_invocation_id: vec3<u32>,
    @builtin(local_invocation_index) local_invoication_index: u32,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
) {
    let workgroup_index =
        workgroup_id.x +
        workgroup_id.y * num_workgroups.x +
        workgroup_id.z * num_workgroups.x * num_workgroups.y;

    let global_invocation_index =
        workgroup_index * 2 * 3 * 4 + local_invoication_index;

    workgroupResult[global_invocation_index] = workgroup_id;
    localResult[global_invocation_index] = local_invocation_id;
    globalResult[global_invocation_index] = global_invocation_id;
}