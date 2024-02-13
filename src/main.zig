const std = @import("std");
const core = @import("mach-core");
const gpu = core.gpu;
const queue = core.queue;

const Renderer = @import("renderer.zig").Renderer;
pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

title_timer: core.Timer,
timer: core.Timer,
renderer: Renderer,

pub fn init(app: *App) !void {
    try core.init(.{
        .title = "Hooray",
        .power_preference = .high_performance,
        .size = .{ .width = 600, .height = 600 },
    });
    core.setFrameRateLimit(5);

    const renderer = try Renderer.init(gpa.allocator());

    app.title_timer = try core.Timer.start();
    app.timer = try core.Timer.start();
    app.renderer = renderer;
}

pub fn deinit(app: *App) void {
    defer _ = gpa.deinit();
    defer core.deinit();

    // TODO how to do this?
    app.renderer.deinit() catch {
        std.debug.print("Failed to deinit renderer\n");
    };
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
