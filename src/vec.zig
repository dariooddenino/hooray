const zm = @import("zmath");

pub const Vec = zm.Vec;

pub fn zero() Vec {
    return zm.splat(0);
}

pub fn new(x: f32, y: f32, z: f32) Vec {
    return Vec{ x, y, z, 0 };
}
