const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const zm = @import("zmath");
const Vertex = @import("cube_mesh.zig").Vertex;
const vertices = @import("cube_mesh.zig").vertices;

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const UniformBufferObject = struct {
    mat: zm.Mat,
};

const workgroup_size = 64;
const buffer_size = 1000;

title_timer: core.Timer,
timer: core.Timer,
pipeline: *gpu.RenderPipeline,
compute_pipeline: *gpu.ComputePipeline,
compute_bind_group: *gpu.BindGroup,
vertex_buffer: *gpu.Buffer,
uniform_buffer: *gpu.Buffer,
output_buffer: *gpu.Buffer,
staging_buffer: *gpu.Buffer,
bind_group: *gpu.BindGroup,
// staging_response: *gpu.Buffer.MapAsyncStatus,

pub fn init(app: *App) !void {
    try core.init(.{});

    const output = core.device.createBuffer(&.{
        .label = "output buffer",
        .usage = .{ .storage = true, .copy_src = true, .copy_dst = true },
        .size = buffer_size * @sizeOf(f32),
        .mapped_at_creation = .false,
    });

    core.queue.writeBuffer(output, 0, &[_]f32{5} ** buffer_size);

    const staging = core.device.createBuffer(&.{
        .label = "staging buffer",
        .usage = .{ .map_read = true, .copy_dst = true },
        .size = buffer_size * @sizeOf(f32),
        .mapped_at_creation = .false,
    });

    const shader_module = core.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    const compute_pipeline = core.device.createComputePipeline(&gpu.ComputePipeline.Descriptor{ .compute = gpu.ProgrammableStageDescriptor{
        .module = shader_module,
        .entry_point = "computeSomething",
    } });
    const compute_pipeline_layout = compute_pipeline.getBindGroupLayout(0);

    const compute_bind_group = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .label = "compute bind group",
            .layout = compute_pipeline_layout,
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, output, 0, buffer_size * @sizeOf(f32)),
            },
        }),
    );

    const vertex_attributes = [_]gpu.VertexAttribute{
        .{ .format = .float32x4, .offset = @offsetOf(Vertex, "pos"), .shader_location = 0 },
        .{ .format = .float32x2, .offset = @offsetOf(Vertex, "uv"), .shader_location = 1 },
    };
    const vertex_buffer_layout = gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(Vertex),
        .step_mode = .vertex,
        .attributes = &vertex_attributes,
    });

    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = core.descriptor.format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "fs",
        .targets = &.{color_target},
    });

    const bgle = gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true }, .uniform, true, 0);
    const bgl = core.device.createBindGroupLayout(
        &gpu.BindGroupLayout.Descriptor.init(.{
            .entries = &.{bgle},
        }),
    );

    const bind_group_layouts = [_]*gpu.BindGroupLayout{bgl};
    const pipeline_layout = core.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &bind_group_layouts,
    }));

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{ .fragment = &fragment, .layout = pipeline_layout, .vertex = gpu.VertexState.init(.{
        .module = shader_module,
        .entry_point = "vs",
        .buffers = &.{vertex_buffer_layout},
    }), .primitive = .{
        .cull_mode = .back,
    } };

    const vertex_buffer = core.device.createBuffer(&.{
        .usage = .{ .vertex = true },
        .size = @sizeOf(Vertex) * vertices.len,
        .mapped_at_creation = .true,
    });
    const vertex_mapped = vertex_buffer.getMappedRange(Vertex, 0, vertices.len);
    @memcpy(vertex_mapped.?, vertices[0..]);
    vertex_buffer.unmap();

    const uniform_buffer = core.device.createBuffer(&.{
        .usage = .{ .copy_dst = true, .uniform = true },
        .size = @sizeOf(UniformBufferObject),
        .mapped_at_creation = .false,
    });
    const bind_group = core.device.createBindGroup(
        &gpu.BindGroup.Descriptor.init(.{
            .layout = bgl,
            .entries = &.{
                gpu.BindGroup.Entry.buffer(0, uniform_buffer, 0, @sizeOf(UniformBufferObject)),
            },
        }),
    );

    // encoder.release();

    // const queue = core.queue;
    // const encoder = core.device.createCommandEncoder(null);

    // TODO this wouldn't work in update.
    // encoder.copyBufferToBuffer(output, 0, staging, 0, buffer_size * @sizeOf(f32));

    // var command = encoder.finish(null);
    // encoder.release();

    // TODO handle better
    // const allocator = gpa.allocator();
    // const staging_response = try allocator.create(gpu.Buffer.MapAsyncStatus);
    // staging_response.* = response;
    // var response: gpu.Buffer.MapAsyncStatus = undefined;
    // const callback = (struct {
    //     pub inline fn callback(ctx: *gpu.Buffer.MapAsyncStatus, status: gpu.Buffer.MapAsyncStatus) void {
    //         ctx.* = status;
    //     }
    // }).callback;
    // staging.mapAsync(.{ .read = true }, 0, buffer_size * @sizeOf(f32), staging_response, callback);

    // var response: gpu.Buffer.MapAsyncStatus = undefined;
    // const callback = (struct {
    //     pub inline fn callback(ctx: *gpu.Buffer.MapAsyncStatus, status: gpu.Buffer.MapAsyncStatus) void {
    //         ctx.* = status;
    //     }
    // }).callback;

    // queue.submit(&[_]*gpu.CommandBuffer{command});
    // command.release();

    // staging.mapAsync(.{ .read = true }, 0, buffer_size * @sizeOf(f32), &response, callback);
    // while (true) {
    //     if (response == gpu.Buffer.MapAsyncStatus.success) {
    //         break;
    //     } else {
    //         core.device.tick();
    //     }
    // }

    // const staging_mapped = staging.getConstMappedRange(f32, 0, buffer_size);
    // for (staging_mapped.?) |v| {
    //     std.debug.print("{d} ", .{v});
    // }
    // std.debug.print("\n", .{});
    // staging.unmap();

    app.title_timer = try core.Timer.start();
    app.timer = try core.Timer.start();
    app.pipeline = core.device.createRenderPipeline(&pipeline_descriptor);
    app.compute_pipeline = compute_pipeline;
    app.compute_bind_group = compute_bind_group;
    app.vertex_buffer = vertex_buffer;
    app.uniform_buffer = uniform_buffer;
    app.bind_group = bind_group;
    app.output_buffer = output;
    app.staging_buffer = staging;
    // app.staging_response = staging_response;

    shader_module.release();
    pipeline_layout.release();
    compute_pipeline_layout.release();
    bgl.release();
}

pub fn deinit(app: *App) void {
    defer _ = gpa.deinit();
    defer core.deinit();

    app.vertex_buffer.release();
    app.uniform_buffer.release();
    app.staging_buffer.release();
    app.output_buffer.release();
    app.bind_group.release();
    app.pipeline.release();
    app.compute_bind_group.release();
    app.compute_pipeline.release();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .key_press => |ev| {
                if (ev.key == .space) return true;
            },
            .close => return true,
            else => {},
        }
    }

    const back_buffer_view = core.swap_chain.getCurrentTextureView().?;
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = std.mem.zeroes(gpu.Color),
        .load_op = .clear,
        .store_op = .store,
    };

    const queue = core.queue;
    const encoder = core.device.createCommandEncoder(null);

    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });

    {
        const time = app.timer.read();
        const model = zm.mul(zm.rotationX(time * (std.math.pi / 2.0)), zm.rotationZ(time * (std.math.pi / 2.0)));
        const view = zm.lookAtRh(
            zm.Vec{ 0, 4, 2, 1 },
            zm.Vec{ 0, 0, 0, 1 },
            zm.Vec{ 0, 0, 1, 0 },
        );
        const proj = zm.perspectiveFovRh(
            (std.math.pi / 4.0),
            @as(f32, @floatFromInt(core.descriptor.width)) / @as(f32, @floatFromInt(core.descriptor.height)),
            0.1,
            10,
        );
        const mvp = zm.mul(zm.mul(model, view), proj);
        const ubo = UniformBufferObject{
            .mat = zm.transpose(mvp),
        };
        queue.writeBuffer(app.uniform_buffer, 0, &[_]UniformBufferObject{ubo});
    }

    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(app.pipeline);
    pass.setVertexBuffer(0, app.vertex_buffer, 0, @sizeOf(Vertex) * vertices.len);
    pass.setBindGroup(0, app.bind_group, &.{0});
    pass.draw(vertices.len, 1, 0, 0);
    pass.end();
    pass.release();

    const compute_pass = encoder.beginComputePass(null);
    compute_pass.setPipeline(app.compute_pipeline);
    compute_pass.setBindGroup(0, app.compute_bind_group, &.{});
    compute_pass.dispatchWorkgroups(try std.math.divCeil(u32, buffer_size, workgroup_size), 1, 1);
    compute_pass.end();
    compute_pass.release();

    encoder.copyBufferToBuffer(app.output_buffer, 0, app.staging_buffer, 0, buffer_size * @sizeOf(f32));

    var command = encoder.finish(null);
    encoder.release();

    var response: gpu.Buffer.MapAsyncStatus = undefined;
    const callback = (struct {
        pub inline fn callback(ctx: *gpu.Buffer.MapAsyncStatus, status: gpu.Buffer.MapAsyncStatus) void {
            ctx.* = status;
        }
    }).callback;

    queue.submit(&[_]*gpu.CommandBuffer{command});
    command.release();

    std.debug.print("mapping\n", .{});
    app.staging_buffer.mapAsync(.{ .read = true }, 0, buffer_size * @sizeOf(f32), &response, callback);
    while (true) {
        if (response == gpu.Buffer.MapAsyncStatus.success) {
            break;
        } else {
            core.device.tick();
        }
    }

    std.debug.print("printing\n", .{});
    const staging_mapped = app.staging_buffer.getConstMappedRange(f32, 0, buffer_size);
    for (staging_mapped.?) |v| {
        std.debug.print("{d} ", .{v});
    }
    std.debug.print("\n", .{});
    app.staging_buffer.unmap();

    core.swap_chain.present();
    back_buffer_view.release();

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Rotating Cube [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}
