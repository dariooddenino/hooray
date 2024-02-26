const std = @import("std");
const builtin = @import("builtin");
const core = @import("mach-core");
const gpu = core.gpu;
const queue = core.queue;

// Enable sysgpu
// pub const mach_core_options = core.ComptimeOptions{
//     .use_wgpu = false,
//     .use_sysgpu = true,
// };

const Renderer = @import("renderer.zig").Renderer;
pub const App = @This();

var gpa = switch (builtin.mode) {
    .Debug => std.heap.GeneralPurposeAllocator(.{ .verbose_log = true, .retain_metadata = true }){},
    else => std.heap.GeneralPurposeAllocator(){},
};
const allocator = gpa.allocator();

// TODO these should be dynamic?
// At least move to a config file
pub const screen_width = 800;
pub const screen_height = 600;
pub const screen_size = 800 * 600;

pub const PressedKeys = packed struct(u16) {
    right: bool = false,
    left: bool = false,
    up: bool = false,
    down: bool = false,
    padding: u12 = undefined,

    pub inline fn areKeysPressed(self: @This()) bool {
        return (self.up or self.down or self.left or self.right);
    }

    pub inline fn clear(self: *@This()) void {
        self.right = false;
        self.left = false;
        self.up = false;
        self.down = false;
    }
};

title_timer: core.Timer,
timer: core.Timer,
renderer: Renderer,
mouse_position: core.Position = .{ .x = 0, .y = 0 },
is_rotating: bool = false,
pressed_keys: PressedKeys = .{},

pub fn init(app: *App) !void {
    const frame_rate = 61;
    try core.init(.{
        .title = "Hooray",
        .power_preference = .high_performance,
        .size = .{ .width = screen_width, .height = screen_height },
    });
    core.setFrameRateLimit(frame_rate);

    const renderer = try Renderer.init(allocator);

    app.title_timer = try core.Timer.start();
    app.timer = try core.Timer.start();
    app.renderer = renderer;
}

pub fn deinit(app: *App) void {
    defer _ = gpa.deinit();
    defer core.deinit();
    defer app.renderer.deinit();
}

pub fn update(app: *App) !bool {
    var iter = core.pollEvents();
    while (iter.next()) |event| {
        switch (event) {
            .key_press, .key_repeat => |ev| {
                if (ev.key == .space) return true;
                if (ev.key == .w or ev.key == .up) app.pressed_keys.up = true;
                if (ev.key == .a or ev.key == .left) app.pressed_keys.left = true;
                if (ev.key == .s or ev.key == .down) app.pressed_keys.down = true;
                if (ev.key == .d or ev.key == .right) app.pressed_keys.right = true;
            },
            .mouse_press => |ev| {
                if (ev.button == .left) {
                    app.is_rotating = true;
                    app.mouse_position = ev.pos;
                }
            },
            .mouse_release => |ev| {
                if (ev.button == .left) {
                    app.is_rotating = false;
                }
            },
            .mouse_motion => |ev| {
                if (app.is_rotating) {
                    // const delta = [2]f32{
                    //     @as(f32, @floatCast((app.mouse_position.x - ev.pos.x) * app.renderer.camera.rotation_speed)),
                    //     @as(f32, @floatCast((app.mouse_position.y - ev.pos.y) * app.renderer.camera.rotation_speed)),
                    // };
                    const delta = [2]f32{
                        @as(f32, @floatCast(app.mouse_position.x - ev.pos.x)),
                        @as(f32, @floatCast(app.mouse_position.y - ev.pos.y)),
                    };
                    app.mouse_position = ev.pos;
                    // app.renderer.camera.rotate(delta);
                    app.renderer.camera.rotate(screen_width, screen_height, delta);
                }
            },
            .close => return true,
            else => {},
        }
    }
    if (app.pressed_keys.areKeysPressed()) {
        app.renderer.camera.calculateMovement(app.pressed_keys);
        app.pressed_keys.clear();
    }
    // NOTE the example was using a "dirty" uniforms flag to determine if they need to be updated in the buffer.

    try app.renderer.render(app);

    // update the window title every second
    if (app.title_timer.read() >= 1.0) {
        app.title_timer.reset();
        try core.printTitle("Hooray [ {d}fps ] [ Input {d}hz ]", .{
            core.frameRate(),
            core.inputRate(),
        });
    }

    return false;
}
