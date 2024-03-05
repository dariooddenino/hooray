const std = @import("std");
const core = @import("mach-core");
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

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    resources: GPUResources,
    scene: Scene,
    uniforms: Uniforms,
    frame_num: f32 = 0,
    camera: *Camera,
    frame_regulator: FrameRegulator = FrameRegulator.init(),
    total_samples: i32 = 0,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        const resources = GPUResources.init(allocator);

        // Build scene
        var scene = Scene.init(allocator);
        try scene.loadBasicScene();
        // try scene.loadWeekOneScene();

        const camera = try allocator.create(Camera);
        camera.* = Camera.init(.{ -4, 4, 2, 0 });

        const uniforms = Uniforms{
            .screen_dims = .{ screen_width, screen_height },
            .frame_num = 0,
            .reset_buffer = 0,
            .view_matrix = camera.view_matrix,
            .eye = camera.eye,
            .defocus_angle = 1,
        };

        var self = Renderer{
            .allocator = allocator,
            .resources = resources,
            .scene = scene,
            .uniforms = uniforms,
            .camera = camera,
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
        const bgl_framebuffer = gpu.BindGroupLayout.Entry.buffer(0, .{ .fragment = true, .compute = true }, .storage, false, 0);
        const bgl_uniforms = gpu.BindGroupLayout.Entry.buffer(1, .{ .vertex = true, .fragment = true, .compute = true }, .uniform, true, 0);
        const bgl_materials = gpu.BindGroupLayout.Entry.buffer(2, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0);
        const bgl_bvh = gpu.BindGroupLayout.Entry.buffer(3, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0);
        const bgl_objects = gpu.BindGroupLayout.Entry.buffer(4, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0);
        const bgl_spheres = gpu.BindGroupLayout.Entry.buffer(5, .{ .fragment = true, .compute = true }, .read_only_storage, false, 0);
        const bgl = core.device.createBindGroupLayout(
            &gpu.BindGroupLayout.Descriptor.init(.{
                .entries = &.{
                    bgl_framebuffer,
                    bgl_uniforms,
                    bgl_materials,
                    bgl_bvh,
                    bgl_objects,
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
        const scene = self.scene;
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

        const materials_gpu = try Material.toGPU(allocator, scene.materials);
        defer materials_gpu.deinit();
        const materials_buffer = core.device.createBuffer(&.{
            .label = "Materials",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = materials_gpu.items.len * @sizeOf(Material.Material_GPU),
            .mapped_at_creation = .true,
        });
        const materials_mapped = materials_buffer.getMappedRange(Material.Material_GPU, 0, materials_gpu.items.len);
        @memcpy(materials_mapped.?, materials_gpu.items[0..]);
        materials_buffer.unmap();

        const bvh_buffer = core.device.createBuffer(&.{
            .label = "BVH",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = scene.bvh_array.items.len * @sizeOf(Aabb_GPU),
            .mapped_at_creation = .true,
        });
        const bvh_mapped = bvh_buffer.getMappedRange(Aabb_GPU, 0, scene.bvh_array.items.len);
        @memcpy(bvh_mapped.?, scene.bvh_array.items[0..]);
        bvh_buffer.unmap();

        const objects_gpu = try Object.toGPU(allocator, scene.objects);
        defer objects_gpu.deinit();
        const objects_buffer = core.device.createBuffer(&.{
            .label = "Objects",
            .usage = .{ .storage = true, .copy_dst = true },
            .size = objects_gpu.items.len * @sizeOf(Object.Object_GPU),
            .mapped_at_creation = .true,
        });
        const objects_mapped = objects_buffer.getMappedRange(Object.Object_GPU, 0, objects_gpu.items.len);
        @memcpy(objects_mapped.?, objects_gpu.items[0..]);
        objects_buffer.unmap();

        const spheres_gpu = try Sphere.toGPU(allocator, scene.spheres);
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

        var buffers: [7]GPUResources.BufferAdd = .{
            .{ .name = "vertex", .buffer = vertex_buffer },
            .{ .name = "frame", .buffer = frame_buffer },
            .{ .name = "uniforms", .buffer = uniforms_buffer },
            .{ .name = "materials", .buffer = materials_buffer },
            .{ .name = "bvh", .buffer = bvh_buffer },
            .{ .name = "objects", .buffer = objects_buffer },
            .{ .name = "spheres", .buffer = spheres_buffer },
        };
        try self.resources.addBuffers(&buffers);
    }

    fn initBindGroups(self: *Renderer) !void {
        const scene = self.scene;
        const layout = self.resources.getBindGroupLayout("layout");
        const frame_buffer = self.resources.getBuffer("frame");
        const uniforms_buffer = self.resources.getBuffer("uniforms");
        const materials_buffer = self.resources.getBuffer("materials");
        const bvh_buffer = self.resources.getBuffer("bvh");
        const objects_buffer = self.resources.getBuffer("objects");
        const spheres_buffer = self.resources.getBuffer("spheres");
        // NOTE here I'm using the lenght of the original arrays instead of the GPU versions.
        const bind_group = core.device.createBindGroup(
            &gpu.BindGroup.Descriptor.init(.{
                .layout = layout,
                .entries = &.{
                    gpu.BindGroup.Entry.buffer(0, frame_buffer, 0, screen_size * @sizeOf(f32)),
                    gpu.BindGroup.Entry.buffer(1, uniforms_buffer, 0, 1 * @sizeOf(Uniforms)),
                    gpu.BindGroup.Entry.buffer(2, materials_buffer, 0, self.scene.materials.items.len * @sizeOf(Material.Material_GPU)),
                    gpu.BindGroup.Entry.buffer(3, bvh_buffer, 0, scene.bvh_array.items.len * @sizeOf(Aabb_GPU)),
                    gpu.BindGroup.Entry.buffer(4, objects_buffer, 0, scene.objects.items.len * @sizeOf(Object.Object_GPU)),
                    gpu.BindGroup.Entry.buffer(5, spheres_buffer, 0, scene.spheres.items.len * @sizeOf(Sphere.Sphere_GPU)),
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
        uniforms.frame_num = self.frame_num;
        uniforms.reset_buffer = if (camera.moving) 1 else 0;

        if (camera.moving) {
            uniforms.rendering = 1;
            self.total_samples = 0;
            self.frame_num = 1;
            camera.moving = false;
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
