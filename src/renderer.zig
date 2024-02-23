const std = @import("std");
const core = @import("mach-core");
const gpu_resources = @import("gpu_resources.zig");
const gpu = core.gpu;
const main = @import("main.zig");
const zm = @import("zmath");
const objects = @import("objects.zig");

const App = @import("main.zig").App;
const Camera = @import("camera.zig").Camera;
const GPUResources = gpu_resources.GPUResources;
const Sphere = objects.Sphere;
const Uniforms = gpu_resources.Uniforms;

const screen_width = main.screen_width;
const screen_height = main.screen_height;
const screen_size = main.screen_width * main.screen_height * 4;

// Output Vertex
const Vertex = struct {
    pos: @Vector(2, f32),
};

// Screen size quad.
const vertex_data = [_]Vertex{ Vertex{ .pos = .{ -1, -1 } }, Vertex{ .pos = .{ 1, -1 } }, Vertex{ .pos = .{ -1, 1 } }, Vertex{ .pos = .{ -1, 1 } }, Vertex{ .pos = .{ 1, -1 } }, Vertex{ .pos = .{ 1, 1 } } };

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    resources: GPUResources,
    uniforms: Uniforms,
    frame_num: f32 = 0,
    camera: *Camera,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        const resources = GPUResources.init(allocator);

        var camera = try allocator.create(Camera);
        camera.* = Camera{};
        camera.setCamera(zm.Vec{ 0, 0, 0, 0 }, zm.Vec{ 3, 3, 3, 0 }, zm.Vec{ 0, 1, 0, 0 });

        const uniforms = Uniforms{
            .screen_dims = .{ screen_width, screen_height },
            .frame_num = 0,
            .reset_buffer = 0,
            .view_matrix = camera.view_matrix,
        };

        var self = Renderer{ .allocator = allocator, .resources = resources, .uniforms = uniforms, .camera = camera };

        // Load shaders
        const shader_module = try loadShaders(allocator);
        defer shader_module.release();

        // Create BindGroupLayouts
        try self.initBindGroupLayouts();

        // Create PipelineLayouts
        try self.initPipelineLayouts();

        // Create Buffers
        try self.initBuffers(allocator);

        // Create BindGroups
        try self.initBindGroups();

        // Create Pipelines
        try self.initPipelines(shader_module);

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        defer self.resources.deinit();
        // TODO this makes the app crash on exit, I'd rather have the leak for now.
        // defer self.allocator.destroy(self.camera);
    }

    fn loadShaders(allocator: std.mem.Allocator) !*gpu.ShaderModule {
        var shader_file = std.ArrayList(u8).init(allocator);
        defer shader_file.deinit();
        const shader_files = .{ "header", "main", "common", "shootRay", "traceRay", "hitRay" };
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
        return core.device.createShaderModuleWGSL("hooray", file);
    }

    fn initBindGroupLayouts(self: *Renderer) !void {
        const bgl_framebuffer = gpu.BindGroupLayout.Entry.buffer(0, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bgl_uniforms = gpu.BindGroupLayout.Entry.buffer(1, .{ .vertex = true, .fragment = true, .compute = true }, .uniform, true, 0);
        const bgl_spheres = gpu.BindGroupLayout.Entry.buffer(2, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0);
        const bgl = core.device.createBindGroupLayout(
            &gpu.BindGroupLayout.Descriptor.init(.{
                .entries = &.{
                    bgl_framebuffer,
                    bgl_uniforms,
                    bgl_spheres,
                },
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

    fn initBuffers(self: *Renderer, allocator: std.mem.Allocator) !void {
        const vertex_buffer = core.device.createBuffer(&.{ .label = "Vertex", .usage = .{ .vertex = true, .copy_dst = true }, .size = @sizeOf(Vertex) * vertex_data.len, .mapped_at_creation = .true });
        const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertex_data.len);
        @memcpy(vertex_mapped.?, vertex_data[0..]);
        vertex_buffer.unmap();

        const frame_num: [screen_size]f32 = .{0} ** screen_size;
        const frame_buffer = core.device.createBuffer(&.{
            .label = "Frame",
            .usage = .{ .storage = true, .copy_src = true },
            .size = @sizeOf(f32) * screen_size,
            .mapped_at_creation = .true,
        });
        const frame_mapped = frame_buffer.getMappedRange(f32, 0, screen_size);
        @memcpy(frame_mapped.?, frame_num[0..]);
        frame_buffer.unmap();

        const uniforms_buffer = core.device.createBuffer(&.{
            .label = "Uniforms",
            .usage = .{ .uniform = true, .copy_dst = true },
            .size = @sizeOf(Uniforms),
            .mapped_at_creation = .false,
        });
        core.queue.writeBuffer(uniforms_buffer, 0, &[_]Uniforms{self.uniforms});

        // Temp code here
        var spheres = std.ArrayList(Sphere).init(allocator);
        defer spheres.deinit();
        try spheres.append(Sphere{ .center = .{ 0, 0, 0, 0 }, .radius = 0.1 });
        const spheres_gpu = try Sphere.toGPU(allocator, spheres);
        defer spheres_gpu.deinit();
        const spheres_buffer = core.device.createBuffer(&.{
            .label = "Spheres",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = spheres_gpu.items.len * @sizeOf(Sphere.Sphere_GPU),
            .mapped_at_creation = .true,
        });
        const spheres_mapped = spheres_buffer.getMappedRange(Sphere.Sphere_GPU, 0, spheres_gpu.items.len);
        @memcpy(spheres_mapped.?, spheres_gpu.items[0..]);
        spheres_buffer.unmap();

        var buffers: [4]GPUResources.BufferAdd = .{
            .{ .name = "vertex", .buffer = vertex_buffer },
            .{ .name = "frame", .buffer = frame_buffer },
            .{ .name = "uniforms", .buffer = uniforms_buffer },
            .{ .name = "spheres", .buffer = spheres_buffer },
        };
        try self.resources.addBuffers(&buffers);
    }

    fn initBindGroups(self: *Renderer) !void {
        const layout = self.resources.getBindGroupLayout("layout");
        const frame_buffer = self.resources.getBuffer("frame");
        const uniforms_buffer = self.resources.getBuffer("uniforms");
        const spheres_buffer = self.resources.getBuffer("spheres");
        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = layout,
                .entries = &.{
                    gpu.BindGroup.Entry.buffer(0, frame_buffer, 0, @sizeOf(f32) * screen_size),
                    gpu.BindGroup.Entry.buffer(1, uniforms_buffer, 0, @sizeOf(Uniforms)),
                    // TODO not using spheres_gpu len here
                    gpu.BindGroup.Entry.buffer(2, spheres_buffer, 0, @sizeOf(Sphere.Sphere_GPU) * 1),
                },
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

        const compute_pipeline = core.device.createComputePipeline(&gpu.ComputePipeline.Descriptor{ .layout = pipeline_layout, .compute = gpu.ProgrammableStageDescriptor{
            .module = shader_module,
            .entry_point = "computeFrameBuffer",
        } });
        var compute_pipelines: [1]GPUResources.ComputePipelineAdd = .{.{ .name = "compute", .compute_pipeline = compute_pipeline }};
        try self.resources.addComputePipelines(&compute_pipelines);
    }

    fn renderPass(self: *Renderer, back_buffer_view: *gpu.TextureView) void {
        const queue = core.queue;
        const descriptor = gpu.CommandEncoder.Descriptor{ .label = "Render encoder" };
        const encoder = core.device.createCommandEncoder(&descriptor);
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
        pass.setBindGroup(0, self.resources.getBindGroup("bind_group"), &.{0});
        pass.setVertexBuffer(0, self.resources.getBuffer("vertex"), 0, @sizeOf(Vertex) * vertex_data.len);

        pass.draw(6, 1, 0, 0);
        pass.end();
        pass.release();
        var command = encoder.finish(null);
        encoder.release();
        queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
    }

    fn computePass(self: *Renderer, work_groups_needed: u32) void {
        const queue = core.queue;
        const descriptor = gpu.CommandEncoder.Descriptor{ .label = "Compute encoder" };
        const encoder = core.device.createCommandEncoder(&descriptor);
        // TODO label here too
        const pass = encoder.beginComputePass(null);
        pass.setPipeline(self.resources.getComputePipeline("compute"));
        pass.setBindGroup(0, self.resources.getBindGroup("bind_group"), &.{0});
        pass.dispatchWorkgroups(work_groups_needed + 1, 1, 1);

        pass.end();
        pass.release();

        var command = encoder.finish(null);
        encoder.release();
        queue.submit(&[_]*gpu.CommandBuffer{command});
        command.release();
    }

    pub fn render(self: *Renderer, app: *App) !void {
        _ = app;
        self.frame_num += 1;
        var uniforms = &self.uniforms;
        const resources = self.resources;
        var camera = self.camera;

        // Update uniforms
        uniforms.frame_num = self.frame_num;
        uniforms.reset_buffer = if (camera.moving or camera.key_press) 1 else 0;

        if (camera.moving or camera.key_press) {
            self.frame_num = 1;
            camera.key_press = false;
        }

        // uniforms.view_matrix = camera.view_matrix;
        const uniforms_buffer = resources.getBuffer("uniforms");
        core.queue.writeBuffer(uniforms_buffer, 0, &[_]Uniforms{uniforms.*});

        // Compute pass

        // Hardcoded for now
        const work_groups_needed = screen_width * screen_height / 64;
        self.computePass(work_groups_needed);

        // Render pass
        const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

        self.renderPass(back_buffer_view);

        core.swap_chain.present();
        back_buffer_view.release();
    }
};
