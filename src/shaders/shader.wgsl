// First WebGPU app example
@group(0) @binding(0) var<uniform> grid: vec2f;
@group(0) @binding(1) var<storage> cellStateIn: array<u32>;
@group(0) @binding(2) var<storage, read_write> cellStateOut: array<u32>;

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
    let state = f32(cellStateIn[input.instance]);

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

fn cellIndex(cell: vec2u) -> u32 {
  return (cell.y % u32(grid.y)) * u32(grid.x) +
         (cell.x % u32(grid.x));

}

fn cellActive(x: u32, y: u32) -> u32 {
  return cellStateIn[cellIndex(vec2(x, y))];
}

@compute
@workgroup_size(8, 8)
fn computeMain(@builtin(global_invocation_id) cell: vec3u) {
  let activeNeighbors = cellActive(cell.x+1, cell.y+1) +
                        cellActive(cell.x+1, cell.y) +
                        cellActive(cell.x+1, cell.y-1) +
                        cellActive(cell.x, cell.y-1) +
                        cellActive(cell.x-1, cell.y-1) +
                        cellActive(cell.x-1, cell.y) +
                        cellActive(cell.x-1, cell.y+1) +
                        cellActive(cell.x, cell.y+1);

  let i = cellIndex(cell.xy);
  // Conway's game of life rules:
  switch activeNeighbors {
    case 2: { // Active cells with 2 neighbors stay active.
      cellStateOut[i] = cellStateIn[i];
    }
    case 3: { // Cells with 3 neighbors become or stay active.
      cellStateOut[i] = 1;
    }
    default: { // Cells with < 2 or > 3 neighbors become inactive.
      cellStateOut[i] = 0;
    }
  }
}