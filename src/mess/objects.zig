const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");

const Vec = @Vector(3, f32);
const Aabb = @import("aabbs.zig").Aabb;

pub const Object = union(enum) {
    sphere: Sphere,
    quad: Quad,
    triangle: Triangle,

    pub fn getBbox(self: Object) Aabb {
        switch (self) {
            inline else => |o| return o.bbox,
        }
    }

    pub fn getType(self: Object) f32 {
        switch (self) {
            inline else => |o| return o.type,
        }
    }
};

// TODO I'm also missing Transform
pub const Sphere = struct {
    center: Vec,
    radius: f32,
    global_id: u32,
    local_id: u32,
    material_id: u32,
    bbox: Aabb,
    type: f32 = 0,

    pub const Sphere_GPU = extern struct {
        center: Vec,
        r: f32,
        global_id: f32,
        local_id: f32,
        material_id: f32,
    };

    pub fn init(center: Vec, radius: f32, global_id: u32, local_id: u32, material_id: u32) Sphere {
        const bbox = Aabb.init(center - zm.splat(Vec, radius), center + zm.splat(Vec, radius));
        return Sphere{ .center = center, .radius = radius, .global_id = global_id, .local_id = local_id, .material_id = material_id, .bbox = bbox };
    }

    pub fn toGPU(allocator: std.mem.Allocator, spheres: std.ArrayList(Sphere)) !std.ArrayList(Sphere_GPU) {
        var spheres_gpu = std.ArrayList(Sphere_GPU).init(allocator);
        for (spheres.items) |sphere| {
            const sphere_gpu = Sphere_GPU{
                .center = sphere.center,
                .r = sphere.radius,
                .global_id = @floatFromInt(sphere.global_id),
                .local_id = @floatFromInt(sphere.local_id),
                .material_id = @floatFromInt(sphere.material_id),
            };
            try spheres_gpu.append(sphere_gpu);
        }
        return spheres_gpu;
    }
};

// TODO I'm also missing Transform
pub const Quad = struct {
    Q: Vec,
    u: Vec,
    local_id: u32,
    v: Vec,
    global_id: u32,
    normal: Vec,
    D: f32,
    w: Vec,
    material_id: u32,
    bbox: Aabb,
    type: f32 = 1,

    pub fn init(Q: Vec, u: Vec, v: Vec, global_id: u32, local_id: u32, material_id: u32) Quad {
        const n = vec.cross(f32, u, v);
        const normal = vec.normalize(f32, n);
        const D = vec.dot(f32, normal, Q)[0];
        const w = n / vec.dot(f32, n, n);

        var bbox = Aabb.init(Q, Q + u + v);
        bbox.pad();

        return Quad{
            .Q = Q,
            .u = u,
            .local_id = local_id,
            .v = v,
            .global_id = global_id,
            .normal = normal,
            .D = D,
            .w = w,
            .material_id = material_id,
            .bbox = bbox,
        };
    }
};

pub const Triangle = struct {
    global_id: u32,
    local_id: u32,
    material_id: u32,
    bbox: Aabb,
    A: Vec,
    B: Vec,
    C: Vec,
    type: f32 = 2,

    // TODO This is weirder. Uses the mesh_id (material_id here) as the global_id.
    pub fn init(A: Vec, B: Vec, C: Vec, normalA: Vec, normalB: Vec, normalC: Vec, material_id: u32, local_id: u32) Triangle {
        _ = A;
        _ = B;
        _ = C;
        _ = normalA;
        _ = normalB;
        _ = normalC;
        _ = material_id;
        _ = local_id;
    }
};
