const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");
const utils = @import("utils.zig");
const gpu_resources = @import("gpu_resources.zig");
const scenes = @import("scenes.zig");
const objects = @import("objects.zig");

const Camera = @import("camera.zig").Camera;
const GPUResources = gpu_resources.GPUResources;
const Uniforms = gpu_resources.Uniforms;
const Aabb_GPU = @import("aabbs.zig").Aabb_GPU;
const Material = @import("materials.zig").Material;
const Quad = objects.Quad;
const Scene = scenes.Scene;
const Sphere = objects.Sphere;
const Triangle = objects.Triangle;

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

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    resources: GPUResources,
    scene: Scene,
    camera: Camera,
    // TODO this feels out of place here maybe
    uniforms: ?Uniforms = null,
    frame_num: f32 = 0,
    avg_frame_time: f32 = 0,
    last_frame_time: i64 = 0,
    req_frame_delay: f32 = 0,

    pub fn init(allocator: std.mem.Allocator, camera: Camera) !Renderer {
        const resources = GPUResources.init(allocator);

        // Build scene
        var scene = Scene.init(allocator);

        try scene.loadBasicScene();

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

    pub fn setRenderParameters(self: *Renderer, max_fps: f32, camera: ?Camera) void {
        self.frame_num = 0;
        self.avg_frame_time = 0;
        self.last_frame_time = std.time.milliTimestamp();
        self.req_frame_delay = 1000 / max_fps;
        if (camera) |c| {
            self.camera = c;
        }
        // TODO in theory width and height
    }

    pub fn deinit(self: *Renderer) !void {
        try self.resources.deinit();
        self.scene.deinit();
    }

    fn loadShaders(allocator: std.mem.Allocator) !*gpu.ShaderModule {
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
        const file = try shader_file.toOwnedSliceSentinel(0);
        defer allocator.free(file);
        // TODO do I need this?
        // var shader_module = try allocator.create(gpu.ShaderModule);
        // shader_module = core.device.createShaderModuleWGSL("hooray", file);
        // return shader_module;
        return core.device.createShaderModuleWGSL("hooray", file);
    }

    // TODO I don't remember how these are used (i.e. the indexes...)
    fn initBindGroupLayouts(self: *Renderer) !void {
        const bglu = gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true, .fragment = true, .compute = true }, .uniform, true, 0);
        const bgls = gpu.BindGroupLayout.Entry.buffer(1, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bglq = gpu.BindGroupLayout.Entry.buffer(2, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bglf = gpu.BindGroupLayout.Entry.buffer(3, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bglt = gpu.BindGroupLayout.Entry.buffer(4, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bglm = gpu.BindGroupLayout.Entry.buffer(5, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bglb = gpu.BindGroupLayout.Entry.buffer(6, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bgl = core.device.createBindGroupLayout(
            &gpu.BindGroupLayout.Descriptor.init(.{
                .entries = &.{
                    bglu,
                    bgls,
                    bglq,
                    bglf,
                    bglt,
                    bglm,
                    bglb,
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

    // TODO for now I'm hardcoding a lot of things.
    fn initBuffers(self: *Renderer, allocator: std.mem.Allocator, scene: Scene, camera: Camera, width: f32, height: f32) !void {
        _ = allocator;

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

        const spheres_buffer = core.device.createBuffer(&.{
            .label = "Spheres",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = scene.spheres.items.len * @sizeOf(Sphere),
            .mapped_at_creation = .true,
        });
        const spheres_mapped = spheres_buffer.getMappedRange(Sphere, 0, scene.spheres.items.len);
        @memcpy(spheres_mapped.?, scene.spheres.items[0..]);
        spheres_buffer.unmap();

        const quads_buffer = core.device.createBuffer(&.{
            .label = "Quads",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = scene.quads.items.len * @sizeOf(Quad),
            .mapped_at_creation = .true,
        });
        if (scene.quads.items.len > 0) {
            const quads_mapped = quads_buffer.getMappedRange(Quad, 0, scene.quads.items.len);
            @memcpy(quads_mapped.?, scene.quads.items[0..]);
            quads_buffer.unmap();
        }

        const triangles_buffer = core.device.createBuffer(&.{
            .label = "Triangles",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = scene.triangles.items.len * @sizeOf(Triangle),
            .mapped_at_creation = .true,
        });
        // TODO map

        const MT = [13]f32;
        const materials: [1]MT = .{.{0} ** 13};
        const materials_buffer = core.device.createBuffer(&.{
            .label = "Materials",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = materials.len * @sizeOf(MT),
            .mapped_at_creation = .true,
        });
        const materials_mapped = materials_buffer.getMappedRange(MT, 0, materials.len);
        @memcpy(materials_mapped.?, materials[0..]);
        materials_buffer.unmap();

        const bvh_buffer = core.device.createBuffer(&.{
            .label = "BVH",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = scene.bvh_array.items.len * @sizeOf(Aabb_GPU),
            .mapped_at_creation = .true,
        });
        if (scene.bvh_array.items.len > 0) {
            const bvh_mapped = bvh_buffer.getMappedRange(Aabb_GPU, 0, scene.bvh_array.items.len);
            @memcpy(bvh_mapped.?, scene.bvh_array.items[0..]);
            bvh_buffer.unmap();
        }

        var buffers: [8]GPUResources.BufferAdd = .{
            .{ .name = "vertex", .buffer = vertex_buffer },
            .{ .name = "uniforms", .buffer = uniforms_buffer },
            .{ .name = "spheres", .buffer = spheres_buffer },
            .{ .name = "quads", .buffer = quads_buffer },
            .{ .name = "triangles", .buffer = triangles_buffer },
            .{ .name = "materials", .buffer = materials_buffer },
            .{ .name = "bvh", .buffer = bvh_buffer },
            .{ .name = "frame", .buffer = frame_buffer },
        };
        try self.resources.addBuffers(&buffers);
    }

    fn initBindGroups(self: *Renderer) !void {
        const layout = self.resources.getBindGroupLayout("layout");
        const uniforms_buffer = self.resources.getBuffer("uniforms");
        const spheres_buffer = self.resources.getBuffer("spheres");
        const quads_buffer = self.resources.getBuffer("quads");
        const frame_buffer = self.resources.getBuffer("frame");
        const materials_buffer = self.resources.getBuffer("materials");
        const bvh_buffer = self.resources.getBuffer("bvh");
        const triangles_buffer = self.resources.getBuffer("triangles");
        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = layout,
                .entries = &.{
                    gpu.BindGroup.Entry.buffer(0, uniforms_buffer, 0, @sizeOf(Uniforms)),
                    gpu.BindGroup.Entry.buffer(1, spheres_buffer, 0, @sizeOf(Sphere) * self.scene.spheres.items.len),
                    gpu.BindGroup.Entry.buffer(2, quads_buffer, 0, @sizeOf(Quad) * self.scene.quads.items.len),
                    gpu.BindGroup.Entry.buffer(3, frame_buffer, 0, @sizeOf(f32) * size),
                    gpu.BindGroup.Entry.buffer(4, triangles_buffer, 0, @sizeOf(Triangle) * self.scene.triangles.items.len),
                    gpu.BindGroup.Entry.buffer(5, materials_buffer, 0, @sizeOf([13]f32)),
                    gpu.BindGroup.Entry.buffer(6, bvh_buffer, 0, @sizeOf(Aabb_GPU) * self.scene.bvh_array.items.len),
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

    // This would be render_animation
    pub fn render(self: *Renderer, app: *App) !void {
        _ = app;
        self.frame_num += 1;
        // TODO mmm
        var uniforms = &self.uniforms.?;
        const resources = self.resources;
        var camera = &self.camera;

        // Update uniforms
        uniforms.frame_num = self.frame_num;
        uniforms.reset_buffer = if (camera.moving or camera.key_press) 1 else 0;

        if (camera.moving or camera.key_press) {
            self.frame_num = 1;
            camera.key_press = false;
        }

        uniforms.view_matrix = camera.view_matrix;
        const uniforms_buffer = resources.getBuffer("uniforms");
        core.queue.writeBuffer(uniforms_buffer, 0, &[_]Uniforms{uniforms.*});

        // Compute pass

        // Hardcoded for now
        const work_groups_needed = (screen_width * screen_height) / 64;
        self.computePass(work_groups_needed);

        // Render pass
        const back_buffer_view = core.swap_chain.getCurrentTextureView().?;

        self.renderPass(back_buffer_view);

        core.swap_chain.present();
        back_buffer_view.release();

        // VSync & Performance Logging
        const current_time = std.time.milliTimestamp();
        const elapsed_time: f32 = @floatFromInt(current_time - self.last_frame_time);

        if (elapsed_time < self.req_frame_delay) {
            // WAIT frame_delay - elapsed_time
        }

        self.last_frame_time = std.time.milliTimestamp();
    }
};
