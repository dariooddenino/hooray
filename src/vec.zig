const zm = @import("zmath");
const utils = @import("utils.zig");

pub const Vec = zm.Vec;

pub fn zero() Vec {
    return zm.splat(0);
}

pub fn new(x: f32, y: f32, z: f32) Vec {
    return Vec{ x, y, z, 0 };
}

pub fn random() Vec {
    return Vec{ utils.randomDouble(), utils.randomDouble(), utils.randomDouble(), 0 };
}

pub fn randomRange(min: f32, max: f32) Vec {
    return Vec{ utils.randomDoubleRange(min, max), utils.randomDoubleRange(min, max), utils.randomDoubleRange(min, max), 0 };
}
