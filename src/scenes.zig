const std = @import("std");
const zm = @import("zmath");

const Sphere = @import("objects.zig").Sphere;
const Vec = zm.Vec;

pub const Scene = struct {
    allocator: std.mem.Allocator,
    spheres: std.ArrayList(Sphere),

    pub fn init(allocator: std.mem.Allocator) Scene {
        const spheres = std.ArrayList(Sphere).init(allocator);
        return Scene{ .allocator = allocator, .spheres = spheres };
    }

    pub fn deinit(self: *Scene) void {
        self.spheres.deinit();
    }

    pub fn loadBasicScene(self: *Scene) !void {
        try self.addSphere(Vec{ 0, 0, -1, 0 }, 0.5);
        try self.addSphere(Vec{ 0, -100.5, -1, 0 }, 100);
    }

    fn addSphere(self: *Scene, center: Vec, radius: f32) !void {
        const sphere = Sphere{ .center = center, .radius = radius };
        try self.spheres.append(sphere);
    }
};
