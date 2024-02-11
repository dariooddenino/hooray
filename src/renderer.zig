const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;

const App = @import("main.zig").App;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    pipeline: *gpu.RenderPipeline,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        var shaders = std.ArrayList(*gpu.ShaderModule).init(allocator);
        defer shaders.deinit();
        const shader_files = .{ "header", "common", "main", "shootRay", "hitRay", "traceRay", "scatterRay", "importanceSampling" };
        // const shader_module = core.device.createShaderModuleWGSL("triangle.wgsl", @embedFile("./shaders/triangle.wgsl"));
        // defer shader_module.release();
        // TODO how do I concatenate strings??
        const ext = ".wgsl";
        const folder = "./shaders/";
        inline for (shader_files) |file| {
            const file_name = file ++ ext;
            const file_folder = folder ++ file_name;

            const shader_module = core.device.createShaderModuleWGSL(file, @embedFile(file_folder));
            try shaders.append(shader_module);
            defer shader_module.release();
        }
        // for (0..shader_files.len) |i| {
        //     // const file: []const u8 = try std.fmt.allocPrint(allocator, "{s}{s}", .{ shader_files[i], ext });
        //     // defer allocator.free(file);
        //     // const folder_file = try std.fmt.allocPrint(allocator, "{s}{s}", .{ folder, file });
        //     // defer allocator.free(folder_file);
        //     // const file_f: [*:0]const u8 = file[0..];
        //     // const folder_file_f: [*:0]const u8 = folder_file[0..];
        //     const file = try allocator.alloc(u8, shader_files[i].len + ext.len + 1);
        //     std.mem.copyForwards(u8, file, shader_files[i]);
        //     // file[shader_files[i].len] = ext[0..];
        //     for (0..ext.len) |j| {
        //         file[shader_files[i].len + j] = ext[j];
        //     }
        //     const file_folder = try allocator.alloc(u8, folder.len + file.len + 1);
        //     std.mem.copyForwards(u8, file_folder, folder);
        //     for (0..file.len) |j| {
        //         file_folder[folder.len + j] = file[j];
        //     }

        //     const shader_module = core.device.createShaderModuleWGSL(file, @embedFile(file_folder));
        //     shaders.append(shader_module);
        //     defer shader_module.release();
        // }

        // Fragment state
        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };

        const shader_module = core.device.createShaderModule(.{
            shaders.items,
            shaders.items.len,
        });
        const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "frag_main", .targets = &.{color_target} });
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{ .fragment = &fragment, .vertex = gpu.VertexState{ .module = shader_module, .entry_point = "vertex_main" } };
        const pipeline = core.device.createRenderPipeline(&pipeline_descriptor);

        return Renderer{ .pipeline = pipeline };
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
