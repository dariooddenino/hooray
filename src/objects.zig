const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");

const Vec = vec.Vec;

pub const Sphere = struct {
    center: Vec,
    radius: f32,

    pub const Sphere_GPU = extern struct {
        center: [3]f32,
        radius: f32,
    };

    pub fn toGPU(allocator: std.mem.Allocator, spheres: std.ArrayList(Sphere)) !std.ArrayList(Sphere_GPU) {
        var spheres_gpu = std.ArrayList(Sphere_GPU).init(allocator);
        for (spheres.items) |sphere| {
            const sphere_gpu = Sphere_GPU{
                .center = [3]f32{ sphere.center[0], sphere.center[1], sphere.center[2] },
                .radius = sphere.radius,
            };
            try spheres_gpu.append(sphere_gpu);
        }
        return spheres_gpu;
    }
};
