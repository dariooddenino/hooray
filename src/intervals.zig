const std = @import("std");
const utils = @import("utils.zig");

pub const Interval = struct {
    min: f32 = utils.infinity,
    max: f32 = -utils.infinity,

    pub fn contains(self: Interval, x: f32) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Interval, x: f32) bool {
        return self.min < x and x < self.max;
    }

    pub fn clamp(self: Interval, x: f32) f32 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;
        return x;
    }

    pub fn size(self: Interval) f32 {
        return self.max - self.min;
    }

    pub fn expand(self: Interval, delta: f32) Interval {
        const padding = delta / 2.0;
        return Interval{ .min = self.min - padding, .max = self.max + padding };
    }

    pub fn add(self: Interval, displacement: f32) Interval {
        return Interval{ .min = self.min + displacement, .max = self.max + displacement };
    }
};

pub const empty = Interval{ .min = utils.infinity, .max = -utils.infinity };

pub const universe = Interval{ .min = -utils.infinity, .max = utils.infinity };

// NOTE: I couldn't find this on the original.
// I'm assuming the implementation is this.
pub fn fromIntervals(a: Interval, b: Interval) Interval {
    return Interval{ .min = @min(a.min, b.min), .max = @max(a.max, b.max) };
}
