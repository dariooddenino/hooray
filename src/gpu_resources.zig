const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");

pub const Uniforms = extern struct {
    screen_dims: [2]f32,
    frame_num: f32,
    reset_buffer: f32,
    view_matrix: zm.Mat,
    eye: zm.Vec,
    defocus_angle: f32 = 0,
    focus_dist: f32 = 10,
};

pub const GPUResources = struct {
    const BindGroups = std.StringHashMap(*gpu.BindGroup);
    const BindGroupLayouts = std.StringHashMap(*gpu.BindGroupLayout);
    const Buffers = std.StringHashMap(*gpu.Buffer);
    const RenderPipelines = std.StringHashMap(*gpu.RenderPipeline);
    const ComputePipelines = std.StringHashMap(*gpu.ComputePipeline);
    const PipelineLayouts = std.StringHashMap(*gpu.PipelineLayout);
    bind_groups: BindGroups,
    bind_group_layouts: BindGroupLayouts,
    buffers: Buffers,
    render_pipelines: RenderPipelines,
    compute_pipelines: ComputePipelines,
    pipline_layouts: PipelineLayouts,

    pub fn init(allocator: std.mem.Allocator) GPUResources {
        const bind_groups = BindGroups.init(allocator);
        const bind_group_layouts = BindGroupLayouts.init(allocator);
        const buffers = Buffers.init(allocator);
        const render_pipelines = RenderPipelines.init(allocator);
        const compute_pipelines = ComputePipelines.init(allocator);
        const pipeline_layouts = PipelineLayouts.init(allocator);

        return GPUResources{
            .bind_groups = bind_groups,
            .bind_group_layouts = bind_group_layouts,
            .buffers = buffers,
            .render_pipelines = render_pipelines,
            .compute_pipelines = compute_pipelines,
            .pipline_layouts = pipeline_layouts,
        };
    }

    pub fn deinit(self: *GPUResources) void {
        deinitResources(BindGroups, self.bind_groups);
        self.bind_groups.deinit();
        deinitResources(BindGroupLayouts, self.bind_group_layouts);
        self.bind_group_layouts.deinit();
        deinitResources(Buffers, self.buffers);
        self.buffers.deinit();
        deinitResources(RenderPipelines, self.render_pipelines);
        self.render_pipelines.deinit();
        deinitResources(ComputePipelines, self.compute_pipelines);
        self.compute_pipelines.deinit();
        deinitResources(PipelineLayouts, self.pipline_layouts);
        self.pipline_layouts.deinit();
    }

    fn deinitResources(comptime T: type, resources: T) void {
        var it = resources.valueIterator();
        while (it.next()) |entry| {
            switch (@TypeOf(entry)) {
                *gpu.BindGroup => entry.release(),
                *gpu.BindGroupLayout => entry.release(),
                *gpu.Buffer => entry.release(),
                *gpu.RenderPipeline => entry.release(),
                *gpu.ComputePipeline => entry.release(),
                *gpu.PipelineLayout => entry.release(),
                else => {},
            }
        }
    }

    pub const BindGroupLayoutAdd = struct { name: []const u8, bind_group_layout: *gpu.BindGroupLayout };
    pub fn addBindGroupLayouts(self: *GPUResources, layouts: []BindGroupLayoutAdd) !void {
        for (layouts) |bg| {
            try self.bind_group_layouts.put(bg.name, bg.bind_group_layout);
        }
    }

    pub const PipelineLayoutAdd = struct { name: []const u8, pipeline_layout: *gpu.PipelineLayout };
    pub fn addPipelineLayouts(self: *GPUResources, layouts: []PipelineLayoutAdd) !void {
        for (layouts) |pl| {
            try self.pipline_layouts.put(pl.name, pl.pipeline_layout);
        }
    }

    pub const BindGroupAdd = struct { name: []const u8, bind_group: *gpu.BindGroup };
    pub fn addBindGroups(self: *GPUResources, bindGroups: []BindGroupAdd) !void {
        for (bindGroups) |bg| {
            try self.bind_groups.put(bg.name, bg.bind_group);
        }
    }

    pub const BufferAdd = struct { name: []const u8, buffer: *gpu.Buffer };
    pub fn addBuffers(self: *GPUResources, buffers: []BufferAdd) !void {
        for (buffers) |b| {
            try self.buffers.put(b.name, b.buffer);
        }
    }

    pub const RenderPipelineAdd = struct { name: []const u8, render_pipeline: *gpu.RenderPipeline };
    pub fn addRenderPipelines(self: *GPUResources, pipelines: []RenderPipelineAdd) !void {
        for (pipelines) |p| {
            try self.render_pipelines.put(p.name, p.render_pipeline);
        }
    }

    pub const ComputePipelineAdd = struct { name: []const u8, compute_pipeline: *gpu.ComputePipeline };
    pub fn addComputePipelines(self: *GPUResources, pipelines: []ComputePipelineAdd) !void {
        for (pipelines) |p| {
            try self.compute_pipelines.put(p.name, p.compute_pipeline);
        }
    }

    pub fn getBindGroupLayout(self: GPUResources, name: []const u8) *gpu.BindGroupLayout {
        // TODO should handle.
        return self.bind_group_layouts.get(name).?;
    }

    pub fn getBindGroup(self: GPUResources, name: []const u8) *gpu.BindGroup {
        // TODO should handle.
        return self.bind_groups.get(name).?;
    }

    pub fn getBuffer(self: GPUResources, name: []const u8) *gpu.Buffer {
        // TODO should handle.
        return self.buffers.get(name).?;
    }

    pub fn getRenderPipeline(self: GPUResources, name: []const u8) *gpu.RenderPipeline {
        // TODO should handle.
        return self.render_pipelines.get(name).?;
    }

    pub fn getComputePipeline(self: GPUResources, name: []const u8) *gpu.ComputePipeline {
        // TODO should handle.
        return self.compute_pipelines.get(name).?;
    }

    pub fn getPipelineLayout(self: GPUResources, name: []const u8) *gpu.PipelineLayout {
        // TODO should handle.
        return self.pipline_layouts.get(name).?;
    }
};
