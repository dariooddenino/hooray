const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");
const utils = @import("utils.zig");
const gpu_resources = @import("gpu_resources.zig");
const scenes = @import("scenes.zig");

const Camera = @import("camera.zig").Camera;
const GPUResources = gpu_resources.GPUResources;
const Uniforms = gpu_resources.Uniforms;
const Scene = scenes.Scene;

const App = @import("main.zig").App;

// TODO putting these two here for now, no idea if I'm going to use them.
const screen_width = 800;
const screen_height = 600;
const size = screen_width * screen_height * 4;

var step: u32 = 0;

const Vertex = struct {
    pos: @Vector(2, f32),
};

// Screen size quad.
const vertex_data = [_]Vertex{ Vertex{ .pos = .{ -1, -1 } }, Vertex{ .pos = .{ 1, -1 } }, Vertex{ .pos = .{ -1, 1 } }, Vertex{ .pos = .{ -1, 1 } }, Vertex{ .pos = .{ 1, -1 } }, Vertex{ .pos = .{ 1, 1 } } };

// TODO data for the hardcoded quad example
// const Vertex = extern struct { pos: @Vector(2, f32), col: @Vector(3, f32) };
// const vertices = [_]Vertex{
//     .{ .pos = .{ -0.5, -0.5 }, .col = .{ 1, 0, 0 } },
//     .{ .pos = .{ 0.5, -0.5 }, .col = .{ 0, 1, 0 } },
//     .{ .pos = .{ 0.5, 0.5 }, .col = .{ 0, 0, 1 } },
//     .{ .pos = .{ -0.5, 0.5 }, .col = .{ 1, 1, 1 } },
// };
// const index_data = [_]u32{ 0, 1, 2, 2, 3, 0 };

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    resources: GPUResources,
    scene: Scene,
    camera: Camera,
    // TODO this feels out of place here maybe
    uniforms: ?Uniforms = null,

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
        try self.initBindGroupLayouts();

        // Create PipelineLayouts
        try self.initPipelineLayouts();

        // Create Buffers
        // TODO this hardcoded width and height should be removed
        try self.initBuffers(allocator, scene, camera, screen_width, screen_height);

        // Create BindGroups
        try self.initBindGroups();

        // Create Pipelines
        try self.initPipelines(shader_module);

        return self;
    }

    pub fn deinit(self: *Renderer) !void {
        try self.resources.deinit();
        self.scene.deinit();
    }

    fn loadShaders(allocator: std.mem.Allocator) !*gpu.ShaderModule {
        var shader_file = std.ArrayList(u8).init(allocator);
        defer shader_file.deinit();
        const shader_files = .{ "header", "common", "main", "shootRay", "hitRay", "traceRay", "scatterRay", "importanceSampling" };
        // const shader_files = .{"simple"};
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

    fn initBindGroupLayouts(self: *Renderer) !void {
        const bglu = gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true, .fragment = true, .compute = true }, .uniform, true, 0);
        const bglf = gpu.BindGroupLayout.Entry.buffer(1, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bgl = core.device.createBindGroupLayout(
            &gpu.BindGroupLayout.Descriptor.init(.{
                .entries = &.{ bglu, bglf },
            }),
        );
        var bind_group_layouts: [1]GPUResources.BindGroupLayoutAdd = .{.{ .name = "layout", .bind_group_layout = bgl }};
        try self.resources.addBindGroupLayouts(&bind_group_layouts);
    }

    fn initPipelineLayouts(self: *Renderer) !void {
        const bind_group_layout = self.resources.getBindGroupLayout("layout");
        const pipeline_layout = core.device.createPipelineLayout(
            &gpu.PipelineLayout.Descriptor.init(.{
                .bind_group_layouts = &.{bind_group_layout},
            }),
        );
        var pipeline_layouts: [1]GPUResources.PipelineLayoutAdd = .{.{ .name = "layout", .pipeline_layout = pipeline_layout }};
        try self.resources.addPipelineLayouts(&pipeline_layouts);
    }

    // TODO for now I'm hardcoding a lot of things.
    fn initBuffers(self: *Renderer, allocator: std.mem.Allocator, scene: Scene, camera: Camera, width: f32, height: f32) !void {
        _ = allocator;
        _ = scene;

        const vertex_buffer = core.device.createBuffer(&.{ .label = "Vertex", .usage = .{ .vertex = true, .copy_dst = true }, .size = @sizeOf(Vertex) * vertex_data.len, .mapped_at_creation = .true });
        const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertex_data.len);
        @memcpy(vertex_mapped.?, vertex_data[0..]);
        vertex_buffer.unmap();

        self.uniforms = Uniforms{ .screen_dims = .{ width, height }, .frame_num = 0, .reset_buffer = 0, .view_matrix = camera.view_matrix };
        const uniforms_buffer = core.device.createBuffer(&.{
            .label = "Uniforms",
            .usage = .{ .uniform = true, .copy_dst = true },
            .size = @sizeOf(Uniforms),
            .mapped_at_creation = .false,
        });
        core.queue.writeBuffer(uniforms_buffer, 0, &[_]Uniforms{self.uniforms.?});

        // TODO for the example
        // const index_buffer = core.device.createBuffer(&.{
        //     .usage = .{ .index = true },
        //     .size = @sizeOf(u32) * index_data.len,
        //     .mapped_at_creation = .true,
        // });
        // const index_mapped = index_buffer.getMappedRange(u32, 0, index_data.len);
        // @memcpy(index_mapped.?, index_data[0..]);
        // index_buffer.unmap();

        // TODO this will have to become an ArrayList if the values are not hardcoded anymore.
        const frame_num: [size]f32 = .{0} ** size;
        const frame_buffer = core.device.createBuffer(&.{
            .label = "Frame",
            .usage = .{ .storage = true, .copy_src = true },
            .size = @sizeOf(f32) * size,
            .mapped_at_creation = .true,
        });
        const frame_mapped = frame_buffer.getMappedRange(f32, 0, size);
        @memcpy(frame_mapped.?, frame_num[0..]);
        frame_buffer.unmap();

        var buffers: [3]GPUResources.BufferAdd = .{ .{ .name = "vertex", .buffer = vertex_buffer }, .{ .name = "uniforms", .buffer = uniforms_buffer }, .{ .name = "frame", .buffer = frame_buffer } };
        try self.resources.addBuffers(&buffers);
    }

    fn initBindGroups(self: *Renderer) !void {
        const layout = self.resources.getBindGroupLayout("layout");
        const uniforms_buffer = self.resources.getBuffer("uniforms");
        const frame_buffer = self.resources.getBuffer("frame");
        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = layout,
                .entries = &.{ gpu.BindGroup.Entry.buffer(0, uniforms_buffer, 0, @sizeOf(Uniforms)), gpu.BindGroup.Entry.buffer(1, frame_buffer, 0, @sizeOf(f32) * size) },
            }),
        );
        var bind_groups: [1]GPUResources.BindGroupAdd = .{.{ .name = "bind_group", .bind_group = bind_group }};
        try self.resources.addBindGroups(&bind_groups);
    }

    fn initPipelines(self: *Renderer, shader_module: *gpu.ShaderModule) !void {
        const blend = gpu.BlendState{};
        const color_target = gpu.ColorTargetState{
            .format = core.descriptor.format,
            .blend = &blend,
            .write_mask = gpu.ColorWriteMaskFlags.all,
        };
        const fragment = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "fs", .targets = &.{color_target} });
        // TODO QUAD example

        // NOTE the buffer layout indicates how to map stuff from zig to the shader
        const vertex_attributes = [_]gpu.VertexAttribute{.{ .format = .float32x2, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 }};
        const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
            .array_stride = @sizeOf(Vertex),
            .step_mode = .vertex,
            .attributes = &vertex_attributes,
        });
        const pipeline_layout = self.resources.getPipelineLayout("layout");
        // const spheres = scene.spheres;
        const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
            .fragment = &fragment,
            .layout = pipeline_layout,
            .vertex = gpu.VertexState.init(.{
                .module = shader_module,
                .entry_point = "vs",
                .buffers = &.{vertex_buffer_layout},
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

        // TODO example stuff
        pass.setVertexBuffer(0, self.resources.getBuffer("vertex"), 0, @sizeOf(Vertex) * vertex_data.len);
        // pass.setIndexBuffer(self.resources.getBuffer("index"), .uint32, 0, @sizeOf(u32) * index_data.len);
        // pass.drawIndexed(index_data.len, 1, 0, 0, 0);
        // ENDTODO

        // GAME OF LIFE
        // const bind_groups = [2]*gpu.BindGroup{ self.resources.getBindGroup("state_a"), self.resources.getBindGroup("state_b") };
        // pass.setBindGroup(0, bind_groups[step % 2], &.{0});
        // pass.setVertexBuffer(0, vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
        // pass.setIndexBuffer(index_buffer, .uint32, 0, @sizeOf(u32) * index_data.len);
        // pass.setBindGroup(0, self.bind_group, &.{0});
        // pass.drawIndexed(index_data.len, grid_size * grid_size, 0, 0, 0);
        // END GAME OF LIFE

        pass.setBindGroup(0, self.resources.getBindGroup("bind_group"), &.{0});
        // TODO no idea here
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
