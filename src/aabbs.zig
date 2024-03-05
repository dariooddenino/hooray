const std = @import("std");
const zm = @import("zmath");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");

const Interval = intervals.Interval;
const Vec = zm.Vec;
const Vec3 = @Vector(3, f32);

// A representation for the shaders.
pub const Aabb_GPU = extern struct {
    min: [3]f32 = .{ 0, 0, 0 },
    primitive_offset: i32 = -1,
    max: [3]f32 = .{ 0, 0, 0 },
    second_child_offset: i32 = -1,
    n_primitives: u32 = 0,
    axis: i32 = -1,
    padding: [2]f32 = .{ 0, 0 },
};

pub const Aabb = struct {
    min: Vec = Vec{ utils.infinity, utils.infinity, utils.infinity, utils.infinity },
    max: Vec = Vec{ -utils.infinity, -utils.infinity, -utils.infinity, -utils.infinity },

    pub fn init(a: Vec, b: Vec) Aabb {
        return Aabb{
            .min = Vec{ @min(a[0], b[0]), @min(a[1], b[1]), @min(a[2], b[2]), 0 },
            .max = Vec{ @max(a[0], b[0]), @max(a[1], b[1]), @max(a[2], b[2]), 0 },
        };
    }

    pub fn bboxTriangle(self: *Aabb, a: Vec, b: Vec, c: Vec) void {
        self.min = Vec{ @min(a[0], @min(b[0], c[0])), @min(a[1], @min(b[1], c[1])), @min(a[2], @min(b[2], c[2])), 0 };
        self.max = Vec{ @max(a[0], @max(b[0], c[0])), @max(a[1], @max(b[1], c[1])), @max(a[2], @max(b[2], c[2])), 0 };
    }

    pub fn mergeBboxes(a: Aabb, b: Aabb) Aabb {
        const min = Vec{ @min(a.min[0], b.min[0]), @min(a.min[1], b.min[1]), @min(a.min[2], b.min[2]), 0 };
        const max = Vec{ @max(a.max[0], b.max[0]), @max(a.max[1], b.max[1]), @max(a.max[2], b.max[2]), 0 };

        return Aabb{ .min = min, .max = max };
    }

    pub fn mergePoint(self: *Aabb, p: Vec) void {
        self.min = Vec{ @min(self.min[0], p[0]), @min(self.min[1], p[1]), @min(self.min[2], p[2]), 0 };
        self.max = Vec{ @max(self.max[0], p[0]), @max(self.max[1], p[1]), @max(self.max[2], p[2]), 0 };
    }

    pub fn merge(self: *Aabb, a: Aabb) void {
        const merged = mergeBboxes(self.*, a);
        self.min = merged.min;
        self.max = merged.max;
    }

    pub fn pad(self: *Aabb) void {
        const delta: f32 = 0.0001 / 2.0;
        if (self.max[0] - self.min[0] < delta) {
            self.max[0] += delta;
            self.min[0] -= delta;
        }
        if (self.max[1] - self.min[1] < delta) {
            self.max[1] += delta;
            self.min[1] -= delta;
        }
        if (self.max[2] - self.min[2] < delta) {
            self.max[2] += delta;
            self.min[2] -= delta;
        }
    }

    pub fn extent(self: Aabb) Vec {
        return self.max - self.min;
    }

    pub fn centroid(self: Aabb) Vec {
        return (self.min + self.max) / zm.splat(Vec, 2);
    }

    pub fn maxDimension(self: Aabb) usize {
        const d = self.extent();

        if (d[0] > d[1] and d[0] > d[2]) {
            return 0;
        } else if (d[1] > d[2]) {
            return 1;
        } else {
            return 2;
        }
    }

    pub fn surfaceArea(self: Aabb) f32 {
        const bextent = self.extent();
        return bextent[0] * bextent[1] + bextent[1] * bextent[2] + bextent[2] * bextent[0];
    }

    pub fn axis(self: Aabb, a: usize) @Vector(2, f32) {
        return @Vector(2, f32){ self.min[a], self.max[a] };
    }
};
