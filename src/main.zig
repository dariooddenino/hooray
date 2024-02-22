const std = @import("std");
const builtin = @import("builtin");
const core = @import("mach-core");
const gpu = core.gpu;
const queue = core.queue;

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
pub const screen_size = 800 * 600 * 4;

title_timer: core.Timer,
timer: core.Timer,
renderer: Renderer,

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
            .key_press => |ev| {
                if (ev.key == .space) return true;
            },
            .close => return true,
            else => {},
        }
    }

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
