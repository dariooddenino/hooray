const std = @import("std");
const zm = @import("zmath");

const Vec = zm.Vec;

pub const Ray = struct {
    origin: Vec = zm.splat(0),
    direction: Vec = zm.splat(0),
    time: f32 = 0.0,

    pub inline fn at(self: Ray, t: f32) Vec {
        return self.origin + zm.splat(t) * self.direction;
    }
};
