const std = @import("std");
const zm = @import("zmath");

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
        var bbox = Aabb{};
        bbox.bbox(center - radius, center + radius);
        return Sphere{ center, radius, global_id, local_id, material_id, bbox };
    }
};

// TODO I'm missing the create_quad with the flattened structure
// TODO I'm also missing Transform
pub const Quad = struct {
    Q: Vec,
    u: Vec,
    local_id: f32,
    v: Vec,
    global_id: f32,
    normal: Vec,
    D: f32,
    w: Vec,
    material_id: f32,
    bbox: Aabb,
    type: f32 = 1,

    pub fn init(Q: Vec, u: Vec, v: Vec, global_id: f32, local_id: f32, material_id: f32) Quad {
        const n = zm.cross(u, v);
        const normal = zm.normalize2(n);
        const D = zm.dot(normal, Q);
        const w = n / zm.dot(n, n);

        var bbox = Aabb{};
        bbox.bbox(Q, Q + u + v);
        bbox.pad();

        return Quad{
            Q,
            u,
            local_id,
            v,
            global_id,
            normal,
            D,
            w,
            material_id,
            bbox,
        };
    }
};
