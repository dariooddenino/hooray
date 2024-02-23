const std = @import("std");
const zm = @import("zmath");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");

const Interval = intervals.Interval;
const Vec = @Vector(3, f32);

// A representation for the shaders.
pub const Aabb_GPU = extern struct {
    mins: Vec = Vec{ 0, 0, 0 },
    right_offset: i32 = -1,
    maxs: Vec = Vec{ 0, 0, 0 },
    type: i32 = -1,
    start_id: i32 = -1,
    tri_count: i32 = -1,
    hit_node: i32 = -1,
    miss_node: i32 = -1,
    axis: i32 = -1,
};

pub const Aabb = struct {
    min: Vec = Vec{ utils.infinity, utils.infinity, utils.infinity },
    max: Vec = Vec{ -utils.infinity, -utils.infinity, -utils.infinity },

    pub fn init(a: Vec, b: Vec) Aabb {
        return Aabb{
            .min = Vec{ @min(a[0], b[0]), @min(a[1], b[1]), @min(a[2], b[2]) },
            .max = Vec{ @max(a[0], b[0]), @max(a[1], b[1]), @max(a[2], b[2]) },
        };
    }

    pub fn bboxTriangle(self: *Aabb, a: Vec, b: Vec, c: Vec) void {
        self.min = Vec{
            @min(a[0], @min(b[0], c[0])),
            @min(a[1], @min(b[1], c[1])),
            @min(a[2], @min(b[2], c[2])),
        };
        self.max = Vec{
            @max(a[0], @max(b[0], c[0])),
            @max(a[1], @max(b[1], c[1])),
            @max(a[2], @max(b[2], c[2])),
        };
    }

    pub fn mergeBbox(a: Aabb, b: Aabb) Aabb {
        const min = Vec{
            @min(a.min[0], b.min[0]),
            @min(a.min[1], b.min[1]),
            @min(a.min[2], b.min[2]),
        };
        const max = Vec{
            @max(a.max[0], b.max[0]),
            @max(a.max[1], b.max[1]),
            @max(a.max[2], b.max[2]),
        };

        return Aabb{ .min = min, .max = max };
    }

    pub fn merge(self: *Aabb, a: Aabb) void {
        const merged = mergeBbox(self.*, a);
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
        const bcentroid = self.centroid();
        if (bcentroid[0] > bcentroid[1] and bcentroid[0] > bcentroid[2]) {
            return 0;
        } else if (bcentroid[1] > bcentroid[2]) {
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