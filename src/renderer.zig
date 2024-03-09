const std = @import("std");
const core = @import("mach").core;
const gpu_resources = @import("gpu_resources.zig");
const gpu = core.gpu;
const main = @import("main.zig");
const zm = @import("zmath");
const objects = @import("objects.zig");
const scenes = @import("scenes.zig");

const Aabb_GPU = @import("aabbs.zig").Aabb_GPU;
const App = @import("main.zig").App;
const Camera = @import("camera.zig").Camera;
const GPUResources = gpu_resources.GPUResources;
const Material = @import("materials.zig").Material;
const Object = objects.Object;
const Quad = objects.Quad;
const Sphere = objects.Sphere;
const Uniforms = gpu_resources.Uniforms;
const Scene = scenes.Scene;

const screen_width = main.screen_width;
const screen_height = main.screen_height;
const screen_size = main.screen_width * main.screen_height * 4;

// Output Vertex
const Vertex = struct {
    pos: [2]f32,
};

// Screen size quad.
const vertex_data = [_]Vertex{ Vertex{ .pos = .{ -1, -1 } }, Vertex{ .pos = .{ 1, -1 } }, Vertex{ .pos = .{ -1, 1 } }, Vertex{ .pos = .{ -1, 1 } }, Vertex{ .pos = .{ 1, -1 } }, Vertex{ .pos = .{ 1, 1 } } };

const FrameRegulator = struct {
    initialized: bool,
    average: f32,
    count: f32,
    last_check: f32,

    fn init() FrameRegulator {
        return FrameRegulator{
            .initialized = false,
            .average = 0,
            .count = 0,
            .last_check = 0,
        };
    }

    // TODO this explodes aftera a while
    fn getDeltaRate(self: *FrameRegulator, frame_rate: u32) i32 {
        const f_rate: f32 = @floatFromInt(frame_rate);
        if (!self.initialized) {
            if (frame_rate > 0) {
                self.average = f_rate;
                self.count = 1;
                self.initialized = true;
            }
        } else if (self.count - self.last_check < 100) {
            // Don't update too often
            self.average = self.average + (f_rate - self.average) / self.count;
            self.count += 1;
        } else {
            self.average = self.average + (f_rate - self.average) / self.count;
            self.count += 1;
            if (self.average < main.target_frame_rate) {
                self.last_check = self.count;
                return -1;
            }
            if (self.average > main.target_frame_rate) {
                self.last_check = self.count;
                return 1;
            }
        }
        return 0;
    }
};

// Idenfies label and buffer position of optional resources.
const OptionalResource = struct {
    label: []const u8,
    position: usize,
    res_type: type,
};

const optional_resources: [4]OptionalResource = .{
    OptionalResource{ .label = "materials", .position = 2, .res_type = Material },
    OptionalResource{ .label = "objects", .position = 4, .res_type = Object },
    OptionalResource{ .label = "spheres", .position = 5, .res_type = Sphere },
    OptionalResource{ .label = "quads", .position = 6, .res_type = Quad },
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    resources: GPUResources,
    scene: Scene,
    uniforms: Uniforms,
    frame_num: f32 = 0,
    camera: *Camera,
    frame_regulator: FrameRegulator = FrameRegulator.init(),
    total_samples: i32 = 0,
    // What do we want to resize it to?
    resize_dims: [2]u32,

    // NOTE this would make more sense in gpu_resources maybe?
    bind_group_layouts: std.ArrayList(gpu.BindGroupLayout.Entry),
    buffer_adds: std.ArrayList(GPUResources.BufferAdd),
    bind_groups: std.ArrayList(gpu.BindGroup.Entry),

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        const resources = GPUResources.init(allocator);

        // Build scene
        var scene = try Scene.init(allocator);
        // try scene.loadTestScene(12);
        // try scene.loadBasicScene();
        try scene.loadWeekOneScene();

        const camera = try allocator.create(Camera);
        camera.* = Camera.init(.{ -4, 4, 2, 0 });

        const uniforms = Uniforms{
            .target_dims = .{ screen_width, screen_height },
            .screen_dims = .{ screen_width, screen_height },
            .frame_num = 0,
            .reset_buffer = 0,
            .view_matrix = camera.view_matrix,
            .eye = camera.eye,
            .defocus_angle = 0.5,
        };

        const bind_group_layouts = std.ArrayList(gpu.BindGroupLayout.Entry).init(allocator);
        const buffer_adds = std.ArrayList(GPUResources.BufferAdd).init(allocator);
        const bind_groups = std.ArrayList(gpu.BindGroup.Entry).init(allocator);

        var self = Renderer{
            .allocator = allocator,
            .resources = resources,
            .scene = scene,
            .uniforms = uniforms,
            .camera = camera,
            .bind_group_layouts = bind_group_layouts,
            .buffer_adds = buffer_adds,
            .bind_groups = bind_groups,
            .resize_dims = .{ screen_width, screen_height },
        };

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
        defer self.scene.deinit();
        defer self.bind_group_layouts.deinit();
        defer self.buffer_adds.deinit();
        defer self.bind_groups.deinit();
        // if (self.bindGroupLayouts) |bgl| {
        //     defer bgl.deinit();
        // }
        defer self.allocator.destroy(self.camera);
    }

    fn loadShaders(allocator: std.mem.Allocator) !*gpu.ShaderModule {
        var shader_file = std.ArrayList(u8).init(allocator);
        defer shader_file.deinit();
        const shader_files = .{ "header", "main", "common", "shootRay", "traceRay", "hitRay", "scatterRay", "importanceSampling" };
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
        var entries = &self.bind_group_layouts;

        // We always have these
        try entries.append(gpu.BindGroupLayout.Entry.buffer(0, .{ .fragment = true, .compute = true }, .storage, false, 0));
        try entries.append(gpu.BindGroupLayout.Entry.buffer(1, .{ .vertex = true, .fragment = true, .compute = true }, .uniform, true, 0));
        try entries.append(gpu.BindGroupLayout.Entry.buffer(3, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0));

        inline for (optional_resources) |l_map| {
            const objs = @field(self.scene, l_map.label);
            if (objs.items.len > 0) {
                try entries.append(gpu.BindGroupLayout.Entry.buffer(l_map.position, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0));
            }
        }

        const bgl = core.device.createBindGroupLayout(
            &gpu.BindGroupLayout.Descriptor.init(.{
                .entries = entries.items,
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

    // Initializes the buffer depending on whether there are resources or not.
    // TODO it doesn't work.
    fn initResourcesBuffer(comptime T: type, allocator: std.mem.Allocator, resources: std.ArrayList(T)) !?*gpu.Buffer {
        const array = try T.toGPU(allocator, resources);
        defer array.deinit();
        const has_elements = array.items.len > 0;
        if (!has_elements) {
            return null;
        }
        const buffer = core.device.createBuffer(&.{
            .label = T.label(),
            .usage = .{ .storage = true, .copy_dst = true },
            .size = array.items.len * @sizeOf(T.GpuType()),
            .mapped_at_creation = .true,
        });
        const mapped = buffer.getMappedRange(T.GpuType(), 0, array.items.len);
        @memcpy(mapped.?, array.items[0..]);
        buffer.unmap();
        return buffer;
    }

    fn initBuffers(self: *Renderer, allocator: std.mem.Allocator) !void {
        const BufferAdd = GPUResources.BufferAdd;
        var entries = &self.buffer_adds;

        const scene = self.scene;
        var vertex_buffer = core.device.createBuffer(&.{ .label = "Vertex", .usage = .{ .vertex = true, .copy_dst = true }, .size = @sizeOf(Vertex) * vertex_data.len, .mapped_at_creation = .true });
        const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertex_data.len);
        @memcpy(vertex_mapped.?, vertex_data[0..]);
        vertex_buffer.unmap();

        try entries.append(BufferAdd{ .name = "vertex", .buffer = vertex_buffer });

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

        try entries.append(BufferAdd{ .name = "frame", .buffer = frame_buffer });

        const uniforms_buffer = core.device.createBuffer(&.{
            .label = "Uniforms",
            .usage = .{ .uniform = true, .copy_dst = true },
            .size = @sizeOf(Uniforms),
            .mapped_at_creation = .false,
        });
        core.queue.writeBuffer(uniforms_buffer, 0, &[_]Uniforms{self.uniforms});

        try entries.append(BufferAdd{ .name = "uniforms", .buffer = uniforms_buffer });

        // NOTE: I can't use this with initResourcesBuffer.
        // It would need some heavy refactoring.
        // NOTE: this will also break in case of no objects in the scene.
        const bvh_buffer = core.device.createBuffer(&.{
            .label = "BVH",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = scene.bvh_array.items.len * @sizeOf(Aabb_GPU),
            .mapped_at_creation = .true,
        });
        const bvh_mapped = bvh_buffer.getMappedRange(Aabb_GPU, 0, scene.bvh_array.items.len);
        @memcpy(bvh_mapped.?, scene.bvh_array.items[0..]);
        bvh_buffer.unmap();

        try entries.append(BufferAdd{ .name = "bvh", .buffer = bvh_buffer });

        inline for (optional_resources) |l_map| {
            const objs = @field(scene, l_map.label);
            const buffer = try initResourcesBuffer(l_map.res_type, allocator, objs);
            if (buffer) |b| {
                try entries.append(BufferAdd{ .name = l_map.label, .buffer = b });
            }
        }

        try self.resources.addBuffers(entries.items);
    }

    fn initBindGroups(self: *Renderer) !void {
        const scene = self.scene;
        var entries = &self.bind_groups;
        const layout = self.resources.getBindGroupLayout("layout");

        const frame_buffer = self.resources.getBuffer("frame");
        try entries.append(gpu.BindGroup.Entry.buffer(0, frame_buffer, 0, screen_size * @sizeOf(f32)));

        const uniforms_buffer = self.resources.getBuffer("uniforms");
        try entries.append(gpu.BindGroup.Entry.buffer(1, uniforms_buffer, 0, 1 * @sizeOf(Uniforms)));

        const bvh_buffer = self.resources.getBuffer("bvh");
        try entries.append(gpu.BindGroup.Entry.buffer(3, bvh_buffer, 0, scene.bvh_array.items.len * @sizeOf(Aabb_GPU)));

        inline for (optional_resources) |op_res| {
            const objs = @field(scene, op_res.label);
            if (objs.items.len > 0) {
                const buffer = self.resources.getBuffer(op_res.label);
                try entries.append(gpu.BindGroup.Entry.buffer(op_res.position, buffer, 0, objs.items.len * @sizeOf(op_res.res_type.GpuType())));
            }
        }

        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = layout,
                .entries = entries.items,
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

    pub fn updateScreenDims(self: *Renderer, width: usize, height: usize) void {
        // const dims: [2]f32 = [_]f32{ @floatFromInt(width), @floatFromInt(height) };
        self.resize_dims = .{ @intCast(width), @intCast(height) };
    }

    pub fn render(self: *Renderer, app: *App) !void {
        _ = app;
        self.frame_num += 1;
        var uniforms = &self.uniforms;
        const resources = self.resources;
        var camera = self.camera;

        // Update uniforms
        const delta_rate = self.frame_regulator.getDeltaRate(core.frameRate());

        self.total_samples += uniforms.sample_rate;
        if (self.total_samples > main.max_samples) {
            uniforms.rendering = 0;
        } else {
            uniforms.sample_rate += delta_rate;
            if (uniforms.sample_rate < 1) {
                uniforms.sample_rate = 1;
            }
        }

        var reset_render = false;

        uniforms.frame_num = self.frame_num;
        uniforms.reset_buffer = 0;

        // TODO resize not working for now
        if (uniforms.screen_dims[0] != self.resize_dims[0] or uniforms.screen_dims[1] != self.resize_dims[1]) {
            uniforms.screen_dims = self.resize_dims;
            // uniforms.target_dims = self.resize_dims;
            // reset_render = true;
        }

        uniforms.reset_buffer = if (camera.moving) 1 else 0;

        if (camera.moving) {
            reset_render = true;
            camera.moving = false;
        }

        if (reset_render) {
            uniforms.rendering = 1;
            self.total_samples = 0;
            self.frame_num = 1;
        }

        uniforms.view_matrix = camera.view_matrix;
        uniforms.eye = camera.eye;
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
