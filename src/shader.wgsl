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

@group(0) @binding(0) var<storage, read_write> output: array<f32>;

@compute @workgroup_size(1) fn computeSomething(
    @builtin(global_invocation_id) id : vec3<u32>,
) {
    output[id.x] = output[id.x] * 2.;
}