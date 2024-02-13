// First WebGPU app example
@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage> cellState: array<u32>;
@group(0) @binding(2) var<storage> cellStateB: array<u32>;

struct VertexInput {
  @location(0) pos: vec2f,
  @location(1) color: vec3f,
  @builtin(instance_index) instance: u32,
};

struct VertexOutput {
  @builtin(position) pos: vec4f,
  @location(0) color: vec3f,
  @location(1) cell: vec2f
};

@vertex
fn vertexMain(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    let i = f32(input.instance);
    let cell = vec2f(i % grid.x, floor(i / grid.x));
    let state = f32(cellState[input.instance]);

    let cellOffset = cell / grid * 2;
    let gridPos = (input.pos*state + 1) / grid - 1 + cellOffset;

    output.pos = vec4(gridPos, 0 ,1);
    output.color = input.color;
    output.cell = cell;
    return output;
}

@fragment
fn fragmentMain(@location(0) color: vec3f, @location(1) cell: vec2f) -> @location(0) vec4<f32> {
  let c = cell / grid;
  return vec4(c, 1-c.x, 1);
}
