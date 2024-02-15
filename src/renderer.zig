const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");
const utils = @import("utils.zig");
const gpu_resources = @import("gpu_resources.zig");
const scenes = @import("scenes.zig");

const Camera = @import("camera.zig").Camera;
const GPUResources = gpu_resources.GPUResources;
const Scene = scenes.Scene;

const App = @import("main.zig").App;

var step: u32 = 0;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    resources: GPUResources,
    scene: Scene,
    camera: Camera,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        const resources = GPUResources.init(allocator);

        // Build scene
        const scene = Scene.init(allocator);
        // scene.loadBasicScene();
        // try scene.createBVH();

        // Create camera
        const camera = Camera{};

        var self = Renderer{ .allocator = allocator, .resources = resources, .scene = scene, .camera = camera };

        // Load shaders
        const shader_module = try loadShaders(allocator);
        defer shader_module.release();

        // Create BindGroupLayouts
        // NOTE I shouldn't need these for now.

        // Create PipelineLayouts
        // NOTE I shouldn't need these for now.

        // Create Buffers

        // Create BindGroups

        // Create Pipelines
        // TODO this hardcoded width and height should be removed
        try self.initPipelines(allocator, scene, camera, shader_module, 800.0, 600.0);

        return self;
    }

    pub fn deinit(self: *Renderer) !void {
        try self.resources.deinit();
        self.scene.deinit();
    }

    fn loadShaders(allocator: std.mem.Allocator) !*gpu.ShaderModule {
        var shader_file = std.ArrayList(u8).init(allocator);
        defer shader_file.deinit();
        // const shader_files = .{ "header", "common", "main", "shootRay", "hitRay", "traceRay", "scatterRay", "importanceSampling" };
        const shader_files = .{"simple"};
        const ext = ".wgsl";
        const folder = "./shaders/";
        inline for (shader_files) |file| {
            const file_name = file ++ ext;
            const file_folder = folder ++ file_name;

            const shader_file_content = @embedFile(file_folder);
            try shader_file.appendSlice(shader_file_content);
        }
        const file = try shader_file.toOwnedSliceSentinel(0);
        defer allocator.free(file);
        // TODO do I need this?
        // var shader_module = try allocator.create(gpu.ShaderModule);
        // shader_module = core.device.createShaderModuleWGSL("hooray", file);
        // return shader_module;
        return core.device.createShaderModuleWGSL("hooray", file);
    }

    // Note this is actually more of a initRenderPipelines...
    fn initPipelines(self: *Renderer, _: std.mem.Allocator, scene: Scene, camera: Camera, shader_module: *gpu.ShaderModule, width: f32, height: f32) !void {
        _ = scene;
        _ = camera;
        _ = width;
        _ = height;
        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };
        const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "fs", .targets = &.{color_target} });
        // const uniforms = GPUResources.Uniforms{ .screen_dims = .{ width, height }, .frame_num = 0, .reset_buffer = 0, .view_matrix = camera.view_matrix };
        // const uniform_array = uniforms.serialize();
        // const spheres = scene.spheres;
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
            .fragment = &fragment,
            // .layout = pipeline_layout,
            .vertex = gpu.VertexState.init(.{
                .module = shader_module,
                .entry_point = "vs",
                // .buffers = &.{vertex_buffer_layout},
            }),
            .primitive = .{
                .cull_mode = .back,
            },
        };
        var render_pipelines: [1]GPUResources.RenderPipelineAdd = .{.{ .name = "render", .render_pipeline = core.device.createRenderPipeline(&pipeline_descriptor) }};
        try self.resources.addRenderPipelines(&render_pipelines);
    }

    pub fn render(self: *Renderer, app: *App) !void {
        _ = app;
        step += 1;
        // const index_buffer = self.resources.getBuffer("index");
        // const vertex_buffer = self.resources.getBuffer("vertex");
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
        pass.setPipeline(self.resources.getRenderPipeline("render"));
        // const bind_groups = [2]*gpu.BindGroup{ self.resources.getBindGroup("state_a"), self.resources.getBindGroup("state_b") };
        // pass.setBindGroup(0, bind_groups[step % 2], &.{0});
        // pass.setVertexBuffer(0, vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
        // pass.setIndexBuffer(index_buffer, .uint32, 0, @sizeOf(u32) * index_data.len);
        // pass.setBindGroup(0, self.bind_group, &.{0});
        // pass.drawIndexed(index_data.len, grid_size * grid_size, 0, 0, 0);
        pass.draw(3, 1, 0, 0);
        pass.end();
        pass.release();

        // const compute_pass = encoder.beginComputePass(null);
        // compute_pass.setPipeline(self.resources.getComputePipeline("compute"));
        // compute_pass.setBindGroup(0, bind_groups[step % 2], &.{0});
        // const workgroup_count = @ceil(grid_size / workgroup_size);
        // compute_pass.dispatchWorkgroups(workgroup_count, workgroup_count, 1);
        // compute_pass.end();
        // compute_pass.release();

        var command = encoder.finish(null);
        encoder.release();

        queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
        core.swap_chain.present();
        back_buffer_view.release();
    }
};
