const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");

const Vec = vec.Vec;
const Aabb = @import("aabbs.zig").Aabb;

pub const ObjectType = enum {
    sphere,
    quad,

    pub fn toType(self: ObjectType) i32 {
        switch (self) {
            .sphere => return 0,
            .quad => return 1,
        }
    }
};

pub const Object = union(enum) {
    sphere: Sphere,
    quad: Quad,

    pub inline fn label() ?[*:0]const u8 {
        return "Object";
    }

    pub inline fn GpuType() type {
        return Object_GPU;
    }

    pub const Object_GPU = extern struct {
        primitive_type: i32,
        primitive_id: u32,
    };

    pub fn getBbox(self: Object) Aabb {
        switch (self) {
            inline else => |o| return o.bbox,
        }
    }

    pub fn getType(self: Object) ObjectType {
        switch (self) {
            inline else => |o| return o.object_type,
        }
    }

    pub fn getLocalId(self: Object) u32 {
        switch (self) {
            inline else => |o| return o.local_id,
        }
    }

    pub fn toGPU(allocator: std.mem.Allocator, objects: std.ArrayList(Object)) !std.ArrayList(Object_GPU) {
        var objects_gpu = std.ArrayList(Object_GPU).init(allocator);
        for (objects.items) |object| {
            const object_gpu = Object_GPU{
                .primitive_type = object.getType().toType(),
                .primitive_id = object.getLocalId(),
            };
            try objects_gpu.append(object_gpu);
        }
        return objects_gpu;
    }
};

pub const Sphere = struct {
    object_type: ObjectType = .sphere,
    center: Vec,
    radius: f32,
    material_id: u32,
    local_id: u32, // Id in its own resource ArrayList
    bbox: Aabb,

    pub inline fn label() ?[*:0]const u8 {
        return "Sphere";
    }

    pub inline fn GpuType() type {
        return Sphere_GPU;
    }

    pub fn init(center: Vec, radius: f32, material_id: u32, local_id: u32) Sphere {
        const bbox = Aabb.init(center - zm.splat(Vec, radius), center + zm.splat(Vec, radius));
        return Sphere{
            .center = center,
            .radius = radius,
            .material_id = material_id,
            .local_id = local_id,
            .bbox = bbox,
        };
    }

    pub const Sphere_GPU = extern struct {
        center: [3]f32,
        radius: f32,
        material_id: f32,
        padding: [3]f32 = .{ 0, 0, 0 },
    };

    pub fn toGPU(allocator: std.mem.Allocator, spheres: std.ArrayList(Sphere)) !std.ArrayList(Sphere_GPU) {
        var spheres_gpu = std.ArrayList(Sphere_GPU).init(allocator);
        for (spheres.items) |sphere| {
            const sphere_gpu = Sphere_GPU{
                .center = zm.vecToArr3(sphere.center),
                .radius = sphere.radius,
                .material_id = @floatFromInt(sphere.material_id),
            };
            try spheres_gpu.append(sphere_gpu);
        }
        return spheres_gpu;
    }
};

pub const Quad = struct {
    object_type: ObjectType = .quad,
    Q: Vec,
    u: Vec,
    v: Vec,
    material_id: u32,
    local_id: u32, // Id in its own resource ArrayList
    bbox: Aabb,
    normal: Vec,
    D: f32,
    w: Vec,

    pub inline fn label() ?[*:0]const u8 {
        return "Quad";
    }

    pub inline fn GpuType() type {
        return Quad_GPU;
    }

    pub fn init(Q: Vec, u: Vec, v: Vec, material_id: u32, local_id: u32) Quad {
        var bbox = Aabb{ .min = Q, .max = Q + u + v };
        bbox.pad();
        const n = zm.cross3(u, v);
        const normal = zm.normalize3(n);
        const D = zm.dot3(normal, Q);
        const w = n / zm.dot3(n, n);
        return Quad{
            .Q = Q,
            .u = u,
            .v = v,
            .material_id = material_id,
            .local_id = local_id,
            .bbox = bbox,
            .normal = normal,
            .D = D[0],
            .w = w,
        };
    }

    pub const Quad_GPU = extern struct {
        Q: [4]f32,
        u: [4]f32,
        v: [4]f32,
        w: [4]f32,
        normal: [4]f32,
        D: f32,
        material_id: f32,
        padding: [2]f32 = .{ 0, 0 },
        // padding0: f32 = 0,
        // padding1: f32 = 0,
        // padding2: f32 = 0,
        // padding1: f32 = 0,
        // padding: [3]f32 = .{ 0, 0, 0 },
    };

    pub fn toGPU(allocator: std.mem.Allocator, quads: std.ArrayList(Quad)) !std.ArrayList(Quad_GPU) {
        var quads_gpu = std.ArrayList(Quad_GPU).init(allocator);
        for (quads.items) |quad| {
            const quad_gpu = Quad_GPU{
                .Q = zm.vecToArr4(quad.Q),
                .u = zm.vecToArr4(quad.u),
                .v = zm.vecToArr4(quad.v),
                .material_id = @floatFromInt(quad.material_id),
                .normal = zm.vecToArr4(quad.normal),
                .D = quad.D,
                .w = zm.vecToArr4(quad.w),
            };
            try quads_gpu.append(quad_gpu);
        }
        return quads_gpu;
    }
};
