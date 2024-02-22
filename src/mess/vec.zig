const std = @import("std");
const zm = @import("zmath");

// TODO consider replacing with handmade below, I'm not sure of how zm funcs work

pub fn cross(comptime T: type, v0: @Vector(3, T), v1: @Vector(3, T)) @Vector(3, T) {
    const res = zm.cross3(zm.loadArr3(v0), zm.loadArr3(v1));
    return zm.vecToArr3(res);
}

pub fn normalize(comptime T: type, v: @Vector(3, T)) @Vector(3, T) {
    const res = zm.normalize2(zm.loadArr3(v));
    return zm.vecToArr3(res);
}

pub fn dot(comptime T: type, v0: @Vector(3, T), v1: @Vector(3, T)) @Vector(3, T) {
    const res = zm.dot2(zm.loadArr3(v0), zm.loadArr3(v1));
    return zm.vecToArr3(res);
}

// pub inline fn dot(u: Vec3, v: Vec3) f32 {
//     return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
// }
// pub inline fn cross(u: Vec3, v: Vec3) Vec3 {
//     return Vec3{ u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0] };
// }

// pub inline fn unitVector(v: Vec3) Vec3 {
//     return v / splat3(length(v));
// }
