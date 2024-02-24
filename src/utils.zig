const std = @import("std");

pub const infinity = std.math.inf(f32);
pub const pi: f32 = 3.1415926535897932385;

pub fn toFloat(v: u32) f32 {
    return @as(f32, @floatFromInt(v));
}

pub inline fn toRadians(degrees: f32) f32 {
    return degrees * pi / 180.0;
}

pub inline fn randomDouble() f32 {
    return std.crypto.random.float(f32);
}

pub inline fn randomDoubleRange(min: f32, max: f32) f32 {
    return min + (max - min) * randomDouble();
}

pub inline fn randomIntRange(min: u32, max: u32) u32 {
    const min_f: f32 = toFloat(min);
    const max_f: f32 = toFloat(max + 1);
    return @intFromFloat(@round(randomDoubleRange(min_f, max_f)));
}

test "randomDouble" {
    const val = randomDouble();
    try std.testing.expect(val > 0 and val < 1);
}
