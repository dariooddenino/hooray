const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

const App = @import("main.zig").App;

// TODO mix: https://github.com/hexops/mach-core/blob/main/examples/deferred-rendering/main.zig
// TODO with: https://github.com/Shridhar2602/WebGPU-Path-Tracer/blob/main/renderer.js
pub const Renderer = struct {
    allocator: std.mem.Allocator,

    // Buffers

    // Bind groups

    // Bind group layouts

    // Pipelines
    compute_pipeline: *gpu.ComputePipeline,
    render_pipeline: *gpu.RenderPipeline,

    // Pipeline layouts

    // Render pass descriptor

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        var shader_file = std.ArrayList(u8).init(allocator);
        defer shader_file.deinit();
        const shader_files = .{ "header", "common", "main", "shootRay", "hitRay", "traceRay", "scatterRay", "importanceSampling" };
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

        // Fragment state
        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };

        const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "frag_main", .targets = &.{color_target} });
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{ .fragment = &fragment, .vertex = gpu.VertexState{ .module = shader_module, .entry_point = "vertex_main" } };
        const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

        return Renderer{ .pipeline = pipeline, .allocator = allocator };
    }

    pub fn deinit(self: *Renderer) void {
        self.pipeline.release();
    }

    // pub fn loadShaders(self: *Renderer) !void {
    //   _ = self;
    // }

    pub fn render(self: *Renderer, app: *App) !void {
        _ = app;
        const queue = core.queue;
        const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
        const color_attachment = gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = std.mem.zeroes(gpu.Color),
            .load_op = .clear,
            .store_op = .store,
        };

        const encoder = core.device.createCommandEncoder(null);
        const render_pass_info = gpu.RenderPassDescriptor.init(.{
            .color_attachments = &.{color_attachment},
        });
        const pass = encoder.beginRenderPass(&render_pass_info);
        pass.setPipeline(self.pipeline);
        pass.draw(3, 1, 0, 0);
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
