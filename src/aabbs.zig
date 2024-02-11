const std = @import("std");
const zm = @import("zmath");
const intervals = @import("intervals.zig");
// const vec = @import("vec.zig");
const rays = @import("rays.zig");
const utils = @import("utils.zig");
// const objects = @import("objects.zig");

const Interval = intervals.Interval;
const Ray = rays.Ray;
const Vec = zm.Vec;

pub const Aabb = struct {
    x: Interval = Interval{ .min = 0, .max = 0 },
    y: Interval = Interval{ .min = 0, .max = 0 },
    z: Interval = Interval{ .min = 0, .max = 0 },

    pub fn fromPoints(a: Vec, b: Vec) Aabb {
        // Treat the two points a and b as extrema for the bounding box, so we don't require a
        // particular minimum/maximum coordinate order.
        const x = Interval{ .min = @min(a[0], b[0]), .max = @max(a[0], b[0]) };
        const y = Interval{ .min = @min(a[1], b[1]), .max = @max(a[1], b[1]) };
        const z = Interval{ .min = @min(a[2], b[2]), .max = @max(a[2], b[2]) };

        return Aabb{ .x = x, .y = y, .z = z };
    }

    pub fn fromBoxes(box0: Aabb, box1: Aabb) Aabb {
        const x = intervals.fromIntervals(box0.x, box1.x);
        const y = intervals.fromIntervals(box0.y, box1.y);
        const z = intervals.fromIntervals(box0.z, box1.z);

        return Aabb{ .x = x, .y = y, .z = z };
    }

    pub fn pad(self: Aabb) Aabb {
        const delta = 0.0001;
        const new_x = if (self.x.size() >= delta) self.x else self.x.expand(delta);
        const new_y = if (self.y.size() >= delta) self.y else self.y.expand(delta);
        const new_z = if (self.z.size() >= delta) self.z else self.z.expand(delta);

        return Aabb{ .x = new_x, .y = new_y, .z = new_z };
    }

    pub fn axis(self: Aabb, n: usize) Interval {
        if (n == 1) return self.y;
        if (n == 2) return self.z;
        return self.x;
    }

    pub fn add(self: Aabb, offset: Vec) Aabb {
        return Aabb{
            .x = self.x.add(offset[0]),
            .y = self.y.add(offset[1]),
            .z = self.z.add(offset[2]),
        };
    }

    pub fn hit(self: Aabb, r: Ray, ray_t: Interval) bool {
        var ray_t_min = ray_t.min;
        var ray_t_max = ray_t.max;

        for (0..3) |a| {
            const invD = 1 / r.direction[a];
            const orig = r.origin[a];

            var t0: f32 = (self.axis(@intCast(a)).min - orig) * invD;
            var t1: f32 = (self.axis(@intCast(a)).max - orig) * invD;

            if (invD < 0) {
                // std.debug.print("SWAPPING\n", .{});
                const temp = t1;
                t1 = t0;
                t0 = temp;
            }

            if (t0 > ray_t_min) ray_t_min = t0;
            if (t1 < ray_t_max) ray_t_max = t1;

            if (ray_t_max <= ray_t_min) return false;
        }
        return true;
    }
};

test "aabb hit" {
    // Unit box
    const aabb = Aabb{ .x = Interval{ .min = -1, .max = 1 }, .y = Interval{ .min = -1, .max = 1 }, .z = Interval{ .min = -1, .max = 1 } };
    const ray_t_o = Interval{ .min = 0.001, .max = utils.infinity };

    const r = Ray{ .origin = Vec{ 13, 2, 3 }, .direction = Vec{ 0, 0, 0 } };
    var ray_t = ray_t_o;

    try std.testing.expect(!aabb.hit(r, &ray_t));

    const r2 = Ray{ .origin = Vec{ 2, 2, 2 }, .direction = Vec{ -1, -1, -1 } };
    var ray_t2 = ray_t_o;

    try std.testing.expect(aabb.hit(r2, &ray_t2));

    const r3 = Ray{ .origin = Vec{ 1, 1, 1 }, .direction = Vec{ -1, -1, -1 } };
    var ray_t3 = ray_t_o;

    try std.testing.expect(aabb.hit(r3, &ray_t3));
}
