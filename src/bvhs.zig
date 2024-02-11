const std = @import("std");
const aabbs = @import("aabbs.zig");
const rays = @import("rays.zig");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");
const materials = @import("materials.zig");
const vec = @import("vec.zig");
const objects = @import("objects.zig");

const Ray = rays.Ray;
const Hittable = objects.Hittable;
const HitRecord = objects.HitRecord;
const Aabb = aabbs.Aabb;
const Interval = intervals.Interval;

pub const BVHTree = struct {
    allocator: std.mem.Allocator,
    root: *const BVHNode,
    bounding_box: Aabb,

    pub fn init(allocator: std.mem.Allocator, src_objects: []Hittable, start: usize, end: usize) !BVHTree {
        const root = try constructTree(allocator, src_objects, start, end);
        return BVHTree{
            .allocator = allocator,
            .root = root,
            .bounding_box = root.bounding_box,
        };
    }

    pub fn deinit(self: *const BVHTree) void {
        BVHNode.deinit(self.allocator, self.root);
    }

    pub fn boundingBox(self: BVHTree) Aabb {
        return self.bounding_box;
    }

    pub fn hit(self: *const BVHTree, ray: Ray, ray_t: Interval) ?HitRecord {
        return self.root.hit(ray, ray_t);
    }

    pub fn constructTree(allocator: std.mem.Allocator, src_objects: []Hittable, start: usize, end: usize) !*BVHNode {
        var left: *BVHNode = undefined;
        var right: *BVHNode = undefined;

        const obj_span = end - start;
        const axis = utils.randomIntRange(0, 2);

        switch (obj_span) {
            1 => {
                return makeLeaf(allocator, &src_objects[start]);
            },
            2 => {
                if (boxComparator(axis, src_objects[start], src_objects[start + 1])) {
                    left = try makeLeaf(allocator, &src_objects[start]);
                    right = try makeLeaf(allocator, &src_objects[start + 1]);
                } else {
                    left = try makeLeaf(allocator, &src_objects[start + 1]);
                    right = try makeLeaf(allocator, &src_objects[start]);
                }
            },
            else => {
                std.sort.heap(Hittable, src_objects[start..end], axis, boxComparator);
                const mid = start + obj_span / 2;
                left = try constructTree(allocator, src_objects, start, mid);
                right = try constructTree(allocator, src_objects, mid, end);
            },
        }
        return makeNode(allocator, left, right, Aabb.fromBoxes(left.bounding_box, right.bounding_box));
    }

    fn makeNode(allocator: std.mem.Allocator, left: *const BVHNode, right: *const BVHNode, bounding_box: Aabb) !*BVHNode {
        const result = try allocator.create(BVHNode);
        result.left = left;
        result.right = right;
        result.leaf = null;
        result.bounding_box = bounding_box;
        return result;
    }

    fn makeLeaf(allocator: std.mem.Allocator, hittable: *const Hittable) !*BVHNode {
        const result = try allocator.create(BVHNode);
        result.leaf = hittable;
        result.left = null;
        result.right = null;
        result.bounding_box = hittable.boundingBox();
        return result;
    }

    fn boxCompare(a: Hittable, b: Hittable, axis_index: u32) bool {
        return a.boundingBox().axis(axis_index).min < b.boundingBox().axis(axis_index).min;
    }

    fn boxComparator(axis: u32, a: Hittable, b: Hittable) bool {
        if (axis == 0) {
            return boxCompare(a, b, 0);
        } else if (axis == 1) {
            return boxCompare(a, b, 1);
        } else {
            return boxCompare(a, b, 2);
        }
    }
};

pub const BVHNode = struct {
    leaf: ?*const Hittable = null,
    left: ?*const BVHNode = null,
    right: ?*const BVHNode = null,
    bounding_box: Aabb = undefined,

    pub fn deinit(allocator: std.mem.Allocator, n: *const BVHNode) void {
        if (n.left) |node| {
            deinit(allocator, node);
        }
        if (n.right) |node| {
            deinit(allocator, node);
        }
        allocator.destroy(n);
    }

    pub fn hit(self: *const BVHNode, ray: Ray, ray_t: Interval) ?HitRecord {
        if (self.leaf) |hittable| {
            return hittable.hit(ray, ray_t);
        }

        if (!self.bounding_box.hit(ray, ray_t)) {
            return null;
        }

        const hit_record_left = self.left.?.hit(ray, ray_t);
        const rInterval = Interval{ .min = ray_t.min, .max = if (hit_record_left != null) hit_record_left.?.t else ray_t.max };
        const hit_record_right = self.right.?.hit(ray, rInterval);

        return hit_record_right orelse hit_record_left orelse null;
    }
};
