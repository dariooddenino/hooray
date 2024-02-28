const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");

const Vec = vec.Vec;

pub const Sphere = struct {
    center: Vec,
    radius: f32,
    material_id: u32,

    pub fn init(center: Vec, radius: f32, material_id: u32) Sphere {
        return Sphere{
            .center = center,
            .radius = radius,
            .material_id = material_id,
        };
    }

    pub const Sphere_GPU = extern struct {
        center: [3]f32,
        radius: f32,
        material_id: f32,
    };

    pub fn toGPU(allocator: std.mem.Allocator, spheres: std.ArrayList(Sphere)) !std.ArrayList(Sphere_GPU) {
        var spheres_gpu = std.ArrayList(Sphere_GPU).init(allocator);
        for (spheres.items) |sphere| {
            const sphere_gpu = Sphere_GPU{
                .center = .{ sphere.center[0], sphere.center[1], sphere.center[2] },
                .radius = sphere.radius,
                .material_id = @floatFromInt(sphere.material_id),
            };
            try spheres_gpu.append(sphere_gpu);
        }
        return spheres_gpu;
    }
};
