const std = @import("std");
const zm = @import("zmath");

const Vec = @Vector(3, f32);

pub const Object = union(enum) {
    sphere: *Sphere,

    pub fn globalId(self: Object) u32 {
        return switch (self) {
            inline else => |o| o.global_id,
        };
    }
};

pub const Sphere = extern struct {
    center: Vec,
    radius: f32,
    global_id: u32,
    local_id: u32,
    material_id: u32,

    pub fn init(center: Vec, radius: f32, global_id: u32, local_id: u32, material_id: u32) Sphere {
        return Sphere{ center, radius, global_id, local_id, material_id };
    }
};

pub const Quad = extern struct {
    Q: Vec,
    u: Vec,
    local_id: f32,
    v: Vec,
    global_id: f32,
    normal: Vec,
    D: f32,
    w: Vec,
    material_id: f32,

    pub fn init(Q: Vec, u: Vec, local_id: f32, v: Vec, global_id: f32, normal: Vec, D: f32, w: Vec, material_id: f32) Quad {
        return Quad{ Q, u, local_id, v, global_id, normal, D, w, material_id };
    }
};
