const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");

const Vec = vec.Vec;
const Aabb = @import("aabbs.zig").Aabb;

pub const ObjectType = enum {
    sphere,

    pub fn toType(self: ObjectType) i32 {
        switch (self) {
            .sphere => return 0,
        }
    }
};

pub const Object = union(enum) {
    sphere: Sphere,

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
                .center = .{ sphere.center[0], sphere.center[1], sphere.center[2] },
                .radius = sphere.radius,
                .material_id = @floatFromInt(sphere.material_id),
            };
            try spheres_gpu.append(sphere_gpu);
        }
        return spheres_gpu;
    }
};
