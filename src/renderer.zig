const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");

// const Vec = zm.Vec;

const App = @import("main.zig").App;

var step: usize = 0;

const Vertex = extern struct { pos: @Vector(2, f32), col: @Vector(3, f32) };

const grid_size: f32 = 32;

const UniformBufferObject = struct { vals: @Vector(2, f32) };
const StateObject = struct { vals: @Vector(grid_size * grid_size, u32) };

const uniform_array: @Vector(2, f32) = .{ grid_size, grid_size };

// const vertices = [6]Vertex{ .{ .pos = .{ -0.8, -0.8, 0, 0 }, .col = .{ 1, 0, 0, 1 } }, .{ .pos = .{ 0.8, -0.8, 0, 0 }, .col = .{ 0, 1, 0, 1 } }, .{ .pos = .{ 0.8, 0.8, 0, 0 }, .col = .{ 0, 0, 1, 1 } }, .{ .pos = .{ -0.8, -0.8, 0, 0 }, .col = .{ 1, 1, 0, 1 } }, .{ .pos = .{ 0.8, 0.8, 0, 0 }, .col = .{ 1, 0, 1, 1 } }, .{ .pos = .{ -0.8, 0.8, 0, 0 }, .col = .{ 0, 1, 1, 1 } } };

const vertices = [_]Vertex{
    .{ .pos = .{ -0.8, -0.8 }, .col = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.8, -0.8 }, .col = .{ 0, 1, 0 } },
    .{ .pos = .{ 0.8, 0.8 }, .col = .{ 0, 0, 1 } },
    .{ .pos = .{ -0.8, 0.8 }, .col = .{ 1, 1, 1 } },
};
const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

// TODO: Once I get it working, I can try the file load stuff, and then moving things out to appropriate
// functions.

// TODO mix: https://github.com/hexops/mach-core/blob/main/examples/deferred-rendering/main.zig
// TODO with: https://github.com/Shridhar2602/WebGPU-Path-Tracer/blob/main/renderer.js
pub const Renderer = struct {
    allocator: std.mem.Allocator,

    // Buffers
    vertex_buffer: *gpu.Buffer,
    index_buffer: *gpu.Buffer,
    uniform_buffer: *gpu.Buffer,
    state_buffer: *gpu.Buffer,

    // Buffer layouts
    // vertex_buffer_layout: gpu.VertexBufferLayout = undefined,

    // Bind groups
    bind_groups: [2]*gpu.BindGroup,

    // Bind group layouts

    // Pipelines
    // compute_pipeline: *gpu.ComputePipeline,
    render_pipeline: *gpu.RenderPipeline,

    // Pipeline layouts

    // Render pass descriptor

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        var shader_file = std.ArrayList(u8).init(allocator);
        defer shader_file.deinit();
        const shader_files = .{"shader"};
        const ext = ".wgsl";
        const folder = "./shaders/";
        inline for (shader_files) |file| {
            const file_name = file ++ ext;
            const file_folder = folder ++ file_name;

            const shader_file_content = @embedFile(file_folder);
            try shader_file.appendSlice(shader_file_content);
        }
        const shader_module = core.device.createShaderModuleWGSL("hooray", try shader_file.toOwnedSliceSentinel(0));
        defer shader_module.release();
        // const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shaders/shader.wgsl"));
        // defer shader_module.release();

        // Buffers layouts
        const vertex_attributes = [_]gpu.VertexAttribute{ .{ .format = .float32x4, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 }, .{ .format = .float32x4, .offset = @offsetOf(Vertex, "col"), .shader_location = 1 } };

        const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
            .array_stride = @sizeOf(Vertex),
            .step_mode = .vertex,
            .attributes = &vertex_attributes,
        });

        // Setting up the bind group layout for the uniform buffer
        const bglu = gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0);
        const bgls = gpu.BindGroupLayout.Entry.buffer(1, .{ .vertex = true, .fragment = true }, .read_only_storage, false, 0);
        const bgl = core.device.createBindGroupLayout(
            &gpu.BindGroupLayout.Descriptor.init(.{
                .entries = &.{ bglu, bgls },
            }),
        );

        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };
        const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "fragmentMain", .targets = &.{color_target} });

        // Pipelines

        const bind_group_layouts = [_]*gpu.BindGroupLayout{bgl};
        const pipeline_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
            .bind_group_layouts = &bind_group_layouts,
        }));
        defer pipeline_layout.release();

        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{ .fragment = &fragment, .layout = pipeline_layout, .vertex = gpu.VertexState.init(.{
            .module = shader_module,
            .entry_point = "vertexMain",
            .buffers = &.{vertex_buffer_layout},
        }), .primitive = .{
            .cull_mode = .back,
        } };

        const vertex_buffer = core.device.createBuffer(&.{
            .label = "Vertex buffer",
            .usage = .{ .vertex = true, .copy_dst = true },
            .size = @sizeOf(Vertex) * vertices.len,
            .mapped_at_creation = .true,
        });
        const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertices.len);
        @memcpy(vertex_mapped.?, vertices[0..]);
        vertex_buffer.unmap();

        const index_buffer = core.device.createBuffer(&.{
            .usage = .{ .index = true },
            .size = @sizeOf(u32) * index_data.len,
            .mapped_at_creation = .true,
        });
        const index_mapped = index_buffer.getMappedRange(u32, 0, index_data.len);
        @memcpy(index_mapped.?, index_data[0..]);
        index_buffer.unmap();

        const uniform_buffer = core.device.createBuffer(&.{
            .label = "Grid Uniforms",
            .usage = .{ .uniform = true, .copy_dst = true },
            .size = @sizeOf(UniformBufferObject),
            .mapped_at_creation = .false,
        });
        const ubo = UniformBufferObject{ .vals = uniform_array };
        core.queue.writeBuffer(uniform_buffer, 0, &[_]UniformBufferObject{ubo});

        const state_buffer = core.device.createBuffer(&.{
            .label = "Grid State A",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = @sizeOf(StateObject),
            .mapped_at_creation = .false,
        });
        var state_vals: [grid_size * grid_size]u32 = .{0} ** (grid_size * grid_size);
        var i: usize = 0;
        while (i < state_vals.len) : (i += 3) {
            state_vals[i] = 1;
        }
        const state = StateObject{ .vals = @as(@Vector(grid_size * grid_size, u32), state_vals) };
        core.queue.writeBuffer(state_buffer, 0, &[_]StateObject{state});

        const state_buffer_b = core.device.createBuffer(&.{
            .label = "Grid State B",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = @sizeOf(StateObject),
            .mapped_at_creation = .false,
        });
        var state_vals_b: [grid_size * grid_size]u32 = .{0} ** (grid_size * grid_size);
        var j: u32 = 0;
        while (j < state_vals_b.len) : (j += 2) {
            state_vals_b[j] = 1;
        }
        const state_b = StateObject{ .vals = @as(@Vector(grid_size * grid_size, u32), state_vals_b) };
        core.queue.writeBuffer(state_buffer_b, 0, &[_]StateObject{state_b});

        const render_pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

        const bind_group_a = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = bgl,
                .entries = &.{ gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)), gpu.BindGroup.Entry.buffer(1, state_buffer, 0, @sizeOf(StateObject)) },
            }),
        );
        const bind_group_b = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = bgl,
                .entries = &.{ gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)), gpu.BindGroup.Entry.buffer(1, state_buffer_b, 0, @sizeOf(StateObject)) },
            }),
        );

        const bind_groups = .{ bind_group_a, bind_group_b };

        return Renderer{ .allocator = allocator, .vertex_buffer = vertex_buffer, .index_buffer = index_buffer, .render_pipeline = render_pipeline, .bind_groups = bind_groups, .uniform_buffer = uniform_buffer, .state_buffer = state_buffer };
    }

    // pub fn inito(allocator: std.mem.Allocator) !Renderer {
    //     var shader_file = std.ArrayList(u8).init(allocator);
    //     defer shader_file.deinit();
    //     const shader_files = .{ "header", "common", "main", "shootRay", "hitRay", "traceRay", "scatterRay", "importanceSampling" };
    //     const ext = ".wgsl";
    //     const folder = "./shaders/";
    //     inline for (shader_files) |file| {
    //         const file_name = file ++ ext;
    //         const file_folder = folder ++ file_name;

    //         const shader_file_content = @embedFile(file_folder);
    //         try shader_file.appendSlice(shader_file_content);
    //     }
    //     const shader_module = core.device.createShaderModuleWGSL("hooray", try shader_file.toOwnedSliceSentinel(0));
    //     defer shader_module.release();

    //     // Fragment state
    //     const blend = gpu.BlendState{};
    //     const color_target = gpu.ColorTargetState{
    //         .format = core.descriptor.format,
    //         .blend = &blend,
    //         .write_mask = gpu.ColorWriteMaskFlags.all,
    //     };

    //     const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "frag_main", .targets = &.{color_target} });
    //     const pipeline_descriptor = gpu.RenderPipeline.Descriptor{ .fragment = &fragment, .vertex = gpu.VertexState{ .module = shader_module, .entry_point = "vertex_main" } };
    //     const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

    //     return Renderer{ .allocator = allocator };
    // }

    // pub fn initBuffers(self: *Renderer) void {
    //     const vertex_buffer = core.device.createBuffer(&.{
    //         .label = "Vertex buffer",
    //         .usage = .{ .vertex = true, .copy_dst = true },
    //         .size = @sizeOf(f32) * vertices.len,
    //         .mapped_at_creation = .true,
    //     });
    //     const vertex_mapped = vertex_buffer.getMappedRange(f32, 0, vertices.len);
    //     @memcpy(vertex_mapped.?, vertices[0..]);
    //     vertex_buffer.unmap();

    //     const vertex_attributes = [_]gpu.VertexAttribute{.{ .format = .float32x2, .offset = 0, .shader_location = 0 }};

    //     const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
    //         .array_stride = @sizeOf(f32),
    //         .step_mode = .vertex,
    //         .attributes = &vertex_attributes,
    //     });

    //     self.vertex_buffer = vertex_buffer;
    //     self.vertex_buffer_layout = vertex_buffer_layout;
    // }

    pub fn deinit(_: *Renderer) void {
        // self.pipeline.release();
    }

    // pub fn loadShaders(self: *Renderer) !void {
    //   _ = self;
    // }

    pub fn render(self: *Renderer, app: *App) !void {
        _ = app;
        step += 1;
        const queue = core.queue;
        const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
        const encoder = core.device.createCommandEncoder(null);
        const color_attachment = gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        };
        const render_pass_info = gpu.RenderPassDescriptor.init(.{
            .color_attachments = &.{color_attachment},
        });

        const pass = encoder.beginRenderPass(&render_pass_info);
        pass.setPipeline(self.render_pipeline);
        pass.setBindGroup(0, self.bind_groups[step % 2], &.{0});
        pass.setVertexBuffer(0, self.vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
        pass.setIndexBuffer(self.index_buffer, .uint32, 0, @sizeOf(u32) * index_data.len);
        // pass.setBindGroup(0, self.bind_group, &.{0});
        pass.drawIndexed(index_data.len, grid_size * grid_size, 0, 0, 0);
        pass.end();
        pass.release();

        var command = encoder.finish(null);
        encoder.release();

        queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
        core.swap_chain.present();
        back_buffer_view.release();
    }
};
