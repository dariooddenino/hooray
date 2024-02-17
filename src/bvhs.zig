const std = @import("std");
const aabbs = @import("aabbs.zig");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");

const Aabb = aabbs.Aabb;
const Object = @import("objects.zig").Object;
const Vec = @Vector(3, f32);

pub const Aabb_GPU = extern struct {
    mins: Vec,
    right_offset: f32,
    maxs: Vec,
    type: f32,
    start_id: f32,
    tri_count: f32,
    miss_node: f32,
    axis: f32,
};

pub const BVHPair = struct {
    bvh: BVH,
    flattened_array: *std.ArrayList(Aabb_GPU),
};

// TODO deinit here
pub fn buildBVH(objects: *std.ArrayList(Object), flattened_array: *std.ArrayList(Aabb_GPU)) !void {
    var bvh = BVH.createBVH(objects);
    // TODO not sure about this
    bvh.populateLinks(null);

    var flattened_id: usize = 0;

    try bvh.flatten(&flattened_id, flattened_array);

    // return BVHPair{ .bvh = bvh, .flattened_array = flattened_array };
}

// TODO why can't I just use a tree of ids?
pub const BVH = struct {
    left: ?*const BVH = null,
    right: ?*const BVH = null,
    bbox: Aabb = Aabb{},
    obj: ?*const Object = null,

    start_id: f32 = -1,
    tri_count: f32 = 0,

    id: f32 = -1,
    // These two hold the ids.
    hit_node: ?f32 = null,
    miss_node: ?f32 = null,
    right_offset: ?f32 = null,

    axis: u32 = 0,

    fn createBVH(objects: *std.ArrayList(Object)) BVH {
        return generateBVHHierarchy(objects, 0, objects.items.len);
    }

    fn generateBVHHierarchy(objects: *std.ArrayList(Object), start: usize, end: usize) BVH {
        var node = BVH{};
        for (start..end) |i| {
            node.bbox.merge(objects.items[i].getBbox());
        }

        // choose the longest axis as the axis to split about
        const extent = node.bbox.extent();
        var axis: u32 = 0;
        if (extent[1] > extent[0]) axis = 1;
        if (extent[2] > extent[axis]) axis = 2;

        const obj_span = end - start;

        // Create a new node. If single object present then it is a leaf node.
        if (obj_span <= 0) {
            node.obj = &objects.items[start];
            node.start_id = @floatFromInt(start);
            node.tri_count = @floatFromInt(end - start + 1);
        } else {
            std.sort.heap(Object, objects.items[start..end], axis, boxCompare);
            // switch (axis) {
            //     1 => std.sort.heap(Object, objects.items[start..end], axis, boxYCompare),
            //     else => std.sort.heap(Object, objects.items[start..end], axis, boxZCompare),
            // }

            // Assign the first half to the left child and the secodn half to the right child.
            const mid = start + obj_span / 2;
            node.left = &generateBVHHierarchy(objects, start, mid);
            node.right = &generateBVHHierarchy(objects, mid, end);
            node.axis = axis;

            node.bbox.mergeBbox(node.left.?.bbox, node.right.?.bbox);
        }

        return node;
    }

    pub fn populateLinks(self: *BVH, next_right_node: ?*const BVH) void {
        if (self.obj) |_| {
            self.hit_node = next_right_node.?.id;
            self.miss_node = self.hit_node;
        } else {
            self.hit_node = self.left.?.id;
            self.miss_node = next_right_node.?.id;
            // TODO This was equaling self.right
            self.right_offset = self.right.?.right_offset.?;

            if (self.left) |_| {
                self.left.?.populateLinks(self.right);
            }
            if (self.right) |_| {
                self.right.?.populateLinks(next_right_node);
            }
        }
    }

    // TODO they were passing the flattened Aabbs
    fn flatten(self: *BVH, flattened_id: *usize, flattened_array: *std.ArrayList(Aabb_GPU)) !void {
        self.id = @floatFromInt(flattened_id.*);
        flattened_id.* += 1;

        var bbox = Aabb_GPU{
            .mins = self.bbox.min,
            .right_offset = self.right_offset.?, // TODO watchout
            .maxs = self.bbox.max,
            .type = -1,
            .start_id = -1,
            .tri_count = -1,
            .miss_node = self.miss_node.?, // TODO watchout
            .axis = @floatFromInt(self.axis),
        };
        if (self.obj) |obj| {
            bbox.type = obj.getType();
            bbox.start_id = self.start_id;
            bbox.tri_count = self.tri_count;
        }
        try flattened_array.append(bbox);
        if (self.left) |_| {
            try self.left.?.flatten(flattened_id, flattened_array);
        }
        if (self.right) |_| {
            try self.right.?.flatten(flattened_id, flattened_array);
        }
    }

    //
    pub fn boxCompare(axis_index: u32, a: Object, b: Object) bool {
        return a.getBbox().axis(axis_index)[0] < b.getBbox().axis(axis_index)[0];
    }

    // pub fn boxXCompare(a: Object, b: Object) bool {
    //     return boxCompare(a, b, 0);
    // }

    // pub fn boxYCompare(a: Object, b: Object) bool {
    //     return boxCompare(a, b, 1);
    // }

    // pub fn boxZCompare(a: Object, b: Object) bool {
    //     return boxCompare(a, b, 2);
    // }

    // TODO Surface Area Heuristic
    pub fn generateBVHHierarchySAH() void {}

    pub fn evaluateSAH() void {}

    pub fn findBestSplitPlan() void {}
};

// const Ray = rays.Ray;
// // const Hittable = objects.Hittable;
// // const HitRecord = objects.HitRecord;
// const Interval = intervals.Interval;
// const Object = @import("objects.zig").Object;

// pub const BVHTree = struct {
//     allocator: std.mem.Allocator,
//     root: *const BVHNode, // TODO Not handling an empty scene here
//     // flat list?

//     pub fn init(allocator: std.mem.Allocator, objects: []Object, start: usize, end: usize) !BVHTree {
//         const root = try constructTree(allocator, objects, start, end);
//         return BVHTree{
//             .allocator = allocator,
//             .root = root,
//         };
//     }

//     pub fn deinit(self: *const BVHTree) void {
//         BVHNode.deinit(self.allocator, self.root);
//     }

//     pub fn constructTree(allocator: std.mem.Allocator, objects: []Object, start: usize, end: usize) !*BVHNode {
//         var left: *BVHNode = undefined;
//         var right: *BVHNode = undefined;

//         const obj_span = end - start;
//         const axis = utils.randomIntRange(0, 2);

//         switch (obj_span) {
//             1 => {
//                 return makeLeaf(allocator, &objects[start]);
//             },
//             2 => {
//                 if (boxComparator(axis, objects[start], objects[start + 1])) {
//                     left = try makeLeaf(allocator, &objects[start]);
//                     right = try makeLeaf(allocator, &objects[start + 1]);
//                 } else {
//                     left = try makeLeaf(allocator, &objects[start + 1]);
//                     right = try makeLeaf(allocator, &objects[start]);
//                 }
//             },
//             else => {
//                 std.sort.heap(Object, objects[start..end], axis, boxComparator);
//                 const mid = start + obj_span / 2;
//                 left = try constructTree(allocator, objects, start, mid);
//                 right = try constructTree(allocator, objects, mid, end);
//             },
//         }
//         return makeNode(allocator, left, right, Aabb.fromBoxes(left.bbox, right.bbox));
//     }

//     fn makeNode(allocator: std.mem.Allocator, left: *const BVHNode, right: *const BVHNode, bbox: Aabb) !*BVHNode {
//         const result = try allocator.create(BVHNode);
//         result.left = left;
//         result.right = right;
//         result.leaf = null;
//         result.bbox = bbox;
//         return result;
//     }

//     fn makeLeaf(allocator: std.mem.Allocator, object: *const Object) !*BVHNode {
//         const result = try allocator.create(BVHNode);
//         result.leaf = object.globalId();
//         result.left = null;
//         result.right = null;
//         result.bbox = object.bBox();
//         return result;
//     }

//     fn boxCompare(a: Object, b: Object, axis_index: u32) bool {
//         return a.bBox().axis(axis_index).min < b.bBox().axis(axis_index).min;
//     }

//     fn boxComparator(axis: u32, a: Object, b: Object) bool {
//         if (axis == 0) {
//             return boxCompare(a, b, 0);
//         } else if (axis == 1) {
//             return boxCompare(a, b, 1);
//         } else {
//             return boxCompare(a, b, 2);
//         }
//     }
// };

// pub const BVHNode = struct {
//     leaf: ?u32,
//     left: ?*const BVHNode,
//     right: ?*const BVHNode,
//     bbox: Aabb,

//     pub fn deinit(allocator: std.mem.Allocator, n: *const BVHNode) void {
//         if (n.left) |node| {
//             deinit(allocator, node);
//         }
//         if (n.right) |node| {
//             deinit(allocator, node);
//         }
//         allocator.destroy(n);
//     }

//     // hit func, maybe this should transform into a suitable structure
// };

// // pub const BVHTree = struct {
// //     allocator: std.mem.Allocator,
// //     root: *const BVHNode,
// //     bounding_box: Aabb,

// //     pub fn init(allocator: std.mem.Allocator, src_objects: []Hittable, start: usize, end: usize) !BVHTree {
// //         const root = try constructTree(allocator, src_objects, start, end);
// //         return BVHTree{
// //             .allocator = allocator,
// //             .root = root,
// //             .bounding_box = root.bounding_box,
// //         };
// //     }

// //     pub fn deinit(self: *const BVHTree) void {
// //         BVHNode.deinit(self.allocator, self.root);
// //     }

// //     pub fn boundingBox(self: BVHTree) Aabb {
// //         return self.bounding_box;
// //     }

// //     pub fn hit(self: *const BVHTree, ray: Ray, ray_t: Interval) ?HitRecord {
// //         return self.root.hit(ray, ray_t);
// //     }

// //     pub fn constructTree(allocator: std.mem.Allocator, src_objects: []Hittable, start: usize, end: usize) !*BVHNode {
// //         var left: *BVHNode = undefined;
// //         var right: *BVHNode = undefined;

// //         const obj_span = end - start;
// //         const axis = utils.randomIntRange(0, 2);

// //         switch (obj_span) {
// //             1 => {
// //                 return makeLeaf(allocator, &src_objects[start]);
// //             },
// //             2 => {
// //                 if (boxComparator(axis, src_objects[start], src_objects[start + 1])) {
// //                     left = try makeLeaf(allocator, &src_objects[start]);
// //                     right = try makeLeaf(allocator, &src_objects[start + 1]);
// //                 } else {
// //                     left = try makeLeaf(allocator, &src_objects[start + 1]);
// //                     right = try makeLeaf(allocator, &src_objects[start]);
// //                 }
// //             },
// //             else => {
// //                 std.sort.heap(Hittable, src_objects[start..end], axis, boxComparator);
// //                 const mid = start + obj_span / 2;
// //                 left = try constructTree(allocator, src_objects, start, mid);
// //                 right = try constructTree(allocator, src_objects, mid, end);
// //             },
// //         }
// //         return makeNode(allocator, left, right, Aabb.fromBoxes(left.bounding_box, right.bounding_box));
// //     }

// //     fn makeNode(allocator: std.mem.Allocator, left: *const BVHNode, right: *const BVHNode, bounding_box: Aabb) !*BVHNode {
// //         const result = try allocator.create(BVHNode);
// //         result.left = left;
// //         result.right = right;
// //         result.leaf = null;
// //         result.bounding_box = bounding_box;
// //         return result;
// //     }

// //     fn makeLeaf(allocator: std.mem.Allocator, hittable: *const Hittable) !*BVHNode {
// //         const result = try allocator.create(BVHNode);
// //         result.leaf = hittable;
// //         result.left = null;
// //         result.right = null;
// //         result.bounding_box = hittable.boundingBox();
// //         return result;
// //     }

// //     fn boxCompare(a: Hittable, b: Hittable, axis_index: u32) bool {
// //         return a.boundingBox().axis(axis_index).min < b.boundingBox().axis(axis_index).min;
// //     }

// //     fn boxComparator(axis: u32, a: Hittable, b: Hittable) bool {
// //         if (axis == 0) {
// //             return boxCompare(a, b, 0);
// //         } else if (axis == 1) {
// //             return boxCompare(a, b, 1);
// //         } else {
// //             return boxCompare(a, b, 2);
// //         }
// //     }
// // };

// // pub const BVHNode = struct {
// //     leaf: ?*const Hittable = null,
// //     left: ?*const BVHNode = null,
// //     right: ?*const BVHNode = null,
// //     bounding_box: Aabb = undefined,

// //     pub fn deinit(allocator: std.mem.Allocator, n: *const BVHNode) void {
// //         if (n.left) |node| {
// //             deinit(allocator, node);
// //         }
// //         if (n.right) |node| {
// //             deinit(allocator, node);
// //         }
// //         allocator.destroy(n);
// //     }

// //     pub fn hit(self: *const BVHNode, ray: Ray, ray_t: Interval) ?HitRecord {
// //         if (self.leaf) |hittable| {
// //             return hittable.hit(ray, ray_t);
// //         }

// //         if (!self.bounding_box.hit(ray, ray_t)) {
// //             return null;
// //         }

// //         const hit_record_left = self.left.?.hit(ray, ray_t);
// //         const rInterval = Interval{ .min = ray_t.min, .max = if (hit_record_left != null) hit_record_left.?.t else ray_t.max };
// //         const hit_record_right = self.right.?.hit(ray, rInterval);

// //         return hit_record_right orelse hit_record_left orelse null;
// //     }
// // };
