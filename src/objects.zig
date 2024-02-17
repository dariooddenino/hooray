const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");

const Vec = @Vector(3, f32);
const Aabb = @import("aabbs.zig").Aabb;

// TODO I need to put back the type here
pub const Object = union(enum) {
    sphere: *Sphere,
    quad: *Quad,

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

// TODO I'm missing the create_sphere with the flattened structure
// TODO I'm also missing Transform
pub const Sphere = struct {
    center: Vec,
    radius: f32,
    global_id: u32,
    local_id: u32,
    material_id: u32,
    bbox: Aabb,
    type: f32 = 0,

    pub fn init(center: Vec, radius: f32, global_id: u32, local_id: u32, material_id: u32) Sphere {
        const bbox = Aabb.init(center - zm.splat(Vec, radius), center + zm.splat(Vec, radius));
        return Sphere{ .center = center, .radius = radius, .global_id = global_id, .local_id = local_id, .material_id = material_id, .bbox = bbox };
    }
};

// TODO I'm missing the create_quad with the flattened structure
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
