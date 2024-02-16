// NOTE: I can mark it as builtin in here...
struct Output {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec3<f32>
};

@vertex
fn vs(
    @location(0) pos: vec2<f32>, @location(1) color: vec3<f32>
) -> Output {
    var output: Output;
    output.pos = vec4(pos, 0, 1);
    output.color = color;
    return output;
}

@fragment
fn fs(@location(0) color: vec3<f32>) -> @location(0) vec4<f32> {
    return vec4(color, 1);
}