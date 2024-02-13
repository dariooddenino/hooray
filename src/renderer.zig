const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");

// const Vec = zm.Vec;

const App = @import("main.zig").App;

const Vertex = extern struct { pos: @Vector(2, f32), col: @Vector(3, f32) };

// const vertices = [6]Vertex{ .{ .pos = .{ -0.8, -0.8, 0, 0 }, .col = .{ 1, 0, 0, 1 } }, .{ .pos = .{ 0.8, -0.8, 0, 0 }, .col = .{ 0, 1, 0, 1 } }, .{ .pos = .{ 0.8, 0.8, 0, 0 }, .col = .{ 0, 0, 1, 1 } }, .{ .pos = .{ -0.8, -0.8, 0, 0 }, .col = .{ 1, 1, 0, 1 } }, .{ .pos = .{ 0.8, 0.8, 0, 0 }, .col = .{ 1, 0, 1, 1 } }, .{ .pos = .{ -0.8, 0.8, 0, 0 }, .col = .{ 0, 1, 1, 1 } } };

const vertices = [_]Vertex{
    .{ .pos = .{ -0.5, -0.5 }, .col = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, -0.5 }, .col = .{ 0, 1, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .col = .{ 0, 0, 1 } },
    .{ .pos = .{ -0.5, 0.5 }, .col = .{ 1, 1, 1 } },
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

    // Buffer layouts
    // vertex_buffer_layout: gpu.VertexBufferLayout = undefined,

    // Bind groups

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

        // Fragment state
        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };

        const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "fragmentMain", .targets = &.{color_target} });

        // Pipelines

        // Why doesn't this need a bind group layout?
        const pipeline_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{}));
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

        const render_pipeline = core.device.createRenderPipeline(&pipeline_descriptor);
        return Renderer{ .allocator = allocator, .vertex_buffer = vertex_buffer, .index_buffer = index_buffer, .render_pipeline = render_pipeline };
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
        pass.setVertexBuffer(0, self.vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
        pass.setIndexBuffer(self.index_buffer, .uint32, 0, @sizeOf(u32) * index_data.len);
        pass.drawIndexed(index_data.len, 1, 0, 0, 0);
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
