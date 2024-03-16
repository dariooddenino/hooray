const std = @import("std");
const aabbs = @import("aabbs.zig");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");
const zm = @import("zmath");

const Aabb = aabbs.Aabb;
const Aabb_GPU = aabbs.Aabb_GPU;
const Object = @import("objects.zig").Object;
const ObjectType = @import("objects.zig").ObjectType;
const SimpleTransform = @import("objects.zig").SimpleTransform;
const Vec = zm.Vec;

const BVHSplitBucket = struct {
    count: u32 = 0,
    bounds: Aabb = Aabb{},
};

// Structure to build the array used for tree construction.
pub const BVHPrimitive = struct {
    primitive_index: usize, // Index in its own type array
    object_type: ObjectType,
    local_index: u32,
    bounds: Aabb,
    centroid: Vec,

    pub fn init(primitive_index: usize, object_type: ObjectType, local_index: u32, bounds: Aabb) BVHPrimitive {
        const centroid = (bounds.min + bounds.max) / zm.splat(Vec, 2.0);
        return BVHPrimitive{
            .primitive_index = primitive_index,
            .object_type = object_type,
            .local_index = local_index,
            .bounds = bounds,
            .centroid = centroid,
        };
    }
};

// Each represent a single node of the BVH tree
pub const BVHBuildNode = struct {
    bounds: Aabb = Aabb{},
    split_axis: usize = 0,
    left: ?*BVHBuildNode = null,
    right: ?*BVHBuildNode = null,
    first_prim_offset: u32 = 0,
    n_primitives: u32 = 0,

    // Build a leaf
    pub fn initLeaf(
        self: *BVHBuildNode,
        first: u32,
        n: usize,
        b: Aabb,
    ) void {
        self.first_prim_offset = first;
        self.n_primitives = @intCast(n);
        self.bounds = b;
        self.left = null;
        self.right = null;
    }

    // Build an interior node, assumes the two nodes have already been created.
    pub fn initInterior(
        self: *BVHBuildNode,
        axis: usize,
        c0: *BVHBuildNode,
        c1: *BVHBuildNode,
    ) void {
        self.left = c0;
        self.right = c1;
        self.bounds = Aabb.mergeBboxes(c0.bounds, c1.bounds);
        self.split_axis = axis;
        self.n_primitives = 0;
    }
};

pub const SplitMethod = enum { SAH, HLBVH, Middle, EqualCounts };

pub const BVHAggregate = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    max_prims_in_node: u32 = 1,
    primitives: *[]Object,
    linear_nodes: std.ArrayList(Aabb_GPU),
    transforms: *std.ArrayList(SimpleTransform),
    split_method: SplitMethod,

    pub fn deinit(self: BVHAggregate) void {
        self.arena.deinit();
    }

    pub fn init(
        in_allocator: std.mem.Allocator,
        primitives: []Object,
        transforms: *std.ArrayList(SimpleTransform),
        split_method: SplitMethod,
    ) !BVHAggregate {
        var arena = std.heap.ArenaAllocator.init(in_allocator);
        const allocator = arena.allocator();

        const max_prims_in_node = 4;

        // Build the array of BVHPrimitive
        var bvh_primitives = std.ArrayList(BVHPrimitive).init(allocator);
        for (0..primitives.len) |i| {
            var bbox = primitives[i].getBbox();
            const n_transform_id = primitives[i].getTransformId();
            if (n_transform_id) |t_id| {
                const transform = transforms.items[t_id];
                bbox = transform.applyToBbox(bbox);
            }

            try bvh_primitives.append(BVHPrimitive.init(
                i,
                primitives[i].getType(),
                primitives[i].getLocalId(),
                // primitives[i].getBbox(),
                bbox,
            ));
        }

        // Root node
        var root: *BVHBuildNode = undefined;
        // Primitives reordered for the BVH
        var ordered_primitives = try std.ArrayList(Object).initCapacity(allocator, primitives.len);
        ordered_primitives.expandToCapacity();
        var total_nodes: u32 = 0;

        const pre_build_t = std.time.milliTimestamp();
        if (split_method == SplitMethod.HLBVH) {
            // Not yet done
            root = try buildHLBVH(allocator, bvh_primitives, &total_nodes, &ordered_primitives);
        } else {
            var ordered_prims_offset: u32 = 0;
            root = try buildRecursive(allocator, &bvh_primitives, &total_nodes, &ordered_prims_offset, &ordered_primitives, primitives, split_method, max_prims_in_node, transforms);
        }
        const post_build_t = std.time.milliTimestamp();
        std.debug.print("BVH of {d} primitives built in {d}ms\n", .{ primitives.len, post_build_t - pre_build_t });
        // printTree(root);

        const ordered_slice = try ordered_primitives.toOwnedSlice();
        const own_primitives = try allocator.create([]Object);
        own_primitives.* = ordered_slice;

        // Convert BVH into compact representation in nodes array
        // Release bvh_primitives
        bvh_primitives.deinit();

        var linear_nodes = try std.ArrayList(Aabb_GPU).initCapacity(allocator, total_nodes);
        linear_nodes.expandToCapacity();
        var offset: usize = 0;
        const pre_flatten_t = std.time.milliTimestamp();
        _ = try flattenBVH(root, &offset, &linear_nodes);
        const post_flatten_t = std.time.milliTimestamp();
        std.debug.print("BVH flattened in {d}ms\n", .{post_flatten_t - pre_flatten_t});
        // printLinearNodes(linear_nodes.items);

        return BVHAggregate{
            .arena = arena,
            .allocator = allocator,
            .max_prims_in_node = max_prims_in_node,
            .primitives = own_primitives,
            .linear_nodes = linear_nodes,
            .transforms = transforms,
            .split_method = split_method,
        };
    }

    pub fn buildHLBVH(
        allocator: std.mem.Allocator,
        bvh_primitives: std.ArrayList(BVHPrimitive),
        total_nodes: *u32,
        ordered_primitives: *std.ArrayList(Object),
    ) !*BVHBuildNode {
        _ = allocator;
        _ = bvh_primitives;
        _ = total_nodes;
        _ = ordered_primitives;
        unreachable;
    }

    pub fn buildRecursive(
        allocator: std.mem.Allocator,
        bvh_primitives: *std.ArrayList(BVHPrimitive),
        total_nodes: *u32,
        ordered_prims_offset: *u32,
        ordered_prims: *std.ArrayList(Object),
        primitives: []Object,
        split_method: SplitMethod,
        max_prims_in_node: u32,
        transforms: *std.ArrayList(SimpleTransform),
    ) !*BVHBuildNode {
        // std.debug.print("\nRECURSIVE STEP (n.prim {d}): ", .{bvh_primitives.items.len});
        // Initialize the node
        var node = try allocator.create(BVHBuildNode);
        node.* = BVHBuildNode{};
        total_nodes.* += 1;

        // Compute bounds of all primitives in BVH node
        var bounds = Aabb{};
        for (bvh_primitives.items) |p| {
            bounds.merge(p.bounds);
        }

        const surface_area = bounds.surfaceArea();
        if (surface_area == 0 or bvh_primitives.items.len == 1) {
            // std.debug.print("no surface or one item\n", .{});
            // Create a leaf
            // NOTE: not sure about that fetch_add here
            const first_prim_offset = ordered_prims_offset.*;
            ordered_prims_offset.* += @intCast(bvh_primitives.items.len);
            for (0..bvh_primitives.items.len) |i| {
                const index = bvh_primitives.items[i].primitive_index;
                ordered_prims.items[first_prim_offset + i] = primitives[index];
            }
            node.initLeaf(first_prim_offset, bvh_primitives.items.len, bounds);
            return node;
        } else {
            // Compute bound of primitive centroids and choose split dimension dim
            var centroid_bounds = Aabb{};
            for (bvh_primitives.items) |p| {
                centroid_bounds.mergePoint(p.centroid);
            }
            const dim = centroid_bounds.maxDimension();
            // std.debug.print("DIM {d}\n", .{dim});

            // Partition primitives into two sets and build children
            if (centroid_bounds.max[dim] == centroid_bounds.min[dim]) {
                // std.debug.print("no bounds\n", .{});
                // Create leaf BVHBuildNode
                const first_prim_offset = ordered_prims_offset.*;
                ordered_prims_offset.* += @intCast(bvh_primitives.items.len);
                for (0..bvh_primitives.items.len) |i| {
                    const index = bvh_primitives.items[i].primitive_index;
                    ordered_prims.items[first_prim_offset + i] = primitives[index];
                }
                node.initLeaf(first_prim_offset, bvh_primitives.items.len, bounds);
                return node;
            } else {
                var mid = bvh_primitives.items.len / 2;
                // std.debug.print("tentative split at {d}\n", .{mid});
                // Partition primtives based on split_method
                switch (split_method) {
                    SplitMethod.Middle => {
                        mid = try splitMiddle(allocator, centroid_bounds, dim, bvh_primitives);
                        if (mid == 0 or mid == bvh_primitives.items.len) {
                            mid = splitEqualCounts(bvh_primitives);
                        }
                    },
                    SplitMethod.EqualCounts => {
                        mid = splitEqualCounts(bvh_primitives);
                    },
                    SplitMethod.SAH => {
                        // directly here for now

                        // Partition primitives using approximate SAH
                        if (bvh_primitives.items.len <= 2) {
                            // std.debug.print("less than 2 prims\n", .{});
                            // Partition primitives into equally sized subsets
                            // TODO not sure
                            mid = bvh_primitives.items.len / 2;
                            // try nthElementPrimitives(bvh_primitives, mid, dim);
                        } else {
                            // Allocate _BVHSplitBucket_ for SAH partition buckets
                            const n_buckets = 12;
                            var buckets: [n_buckets]BVHSplitBucket = .{BVHSplitBucket{}} ** n_buckets;

                            // Initialize buckets for SAH partition
                            for (bvh_primitives.items) |prim| {
                                var b: usize = @intFromFloat(@as(f32, @floatFromInt(n_buckets)) * centroid_bounds.offset(prim.centroid)[dim]);
                                if (b == n_buckets) {
                                    b = n_buckets - 1;
                                }
                                buckets[b].count += 1;
                                buckets[b].bounds.merge(prim.bounds);
                            }

                            // std.debug.print("BUCKETS: {any}\n", .{buckets});

                            // Compute costs for splitting after each bucket
                            const n_splits = n_buckets - 1;
                            var costs: [n_splits]f32 = .{0} ** n_splits;

                            // Partially initialize _costs_ using a forward scan over splits
                            var count_below: u32 = 0;
                            var bound_below = Aabb{};
                            for (0..n_splits) |i| {
                                bound_below.merge(buckets[i].bounds);
                                count_below += buckets[i].count;
                                costs[i] += @as(f32, @floatFromInt(count_below)) * bound_below.surfaceArea();
                            }

                            // Finish initializing _costs_ using a backwrd scan over splits
                            var count_above: u32 = 0;
                            var bound_above = Aabb{};
                            var i: usize = n_splits;
                            while (i >= 1) : (i -= 1) {
                                bound_above.merge(buckets[i].bounds);
                                count_above += buckets[i].count;
                                costs[i - 1] += @as(f32, @floatFromInt(count_above)) * bound_above.surfaceArea();
                            }

                            // Find bucket to split at that minimizes SAH metric
                            var min_cost_split_bucket: i32 = -1;
                            var min_cost = utils.infinity;
                            for (0..n_splits) |j| {
                                // Compute cost for candidate split and update minimum if necessary
                                if (costs[j] < min_cost) {
                                    min_cost = costs[i];
                                    min_cost_split_bucket = @intCast(j);
                                }
                            }

                            //Compute leaf and SAH split cost for chosen split
                            const leaf_cost: f32 = @floatFromInt(bvh_primitives.items.len);
                            min_cost = 1 / 2 + min_cost / bounds.surfaceArea();

                            // Either create leaf or split primitives at selected SAH bucket
                            if (bvh_primitives.items.len > max_prims_in_node or min_cost < leaf_cost) {
                                // std.debug.print("min bucket cost: {d}\n", .{min_cost_split_bucket});

                                mid = partitionArrayList(
                                    BVHPrimitive,
                                    bvh_primitives,
                                    CompareBucketContext{ .n_buckets = n_buckets, .dim = dim, .min_cost_split_bucket = min_cost_split_bucket, .centroid_bounds = centroid_bounds },
                                    comparePrimToBuckets,
                                );
                                // std.debug.print("new mid point {d}\n", .{mid});
                            } else {
                                // std.debug.print("SAH leaf\n", .{});
                                // Create leaf _BVHBuildNode_
                                const first_prim_offset = ordered_prims_offset.*;
                                ordered_prims_offset.* += @intCast(bvh_primitives.items.len);
                                for (0..bvh_primitives.items.len) |j| {
                                    const index = bvh_primitives.items[j].primitive_index;
                                    ordered_prims.items[first_prim_offset + j] = primitives[index];
                                }
                                node.initLeaf(first_prim_offset, bvh_primitives.items.len, bounds);
                                return node;
                            }
                        }
                    },
                    SplitMethod.HLBVH => {},
                }

                // It's a tentative...
                var left_clone = try bvh_primitives.clone();
                // defer left_clone.deinit();
                var left_slice = try left_clone.toOwnedSlice();
                defer allocator.free(left_slice);
                var left_primitives = std.ArrayList(BVHPrimitive).fromOwnedSlice(allocator, left_slice[0..mid]);
                defer left_primitives.deinit();

                var right_clone = try bvh_primitives.clone();
                // defer right_clone.deinit();
                var right_slice = try right_clone.toOwnedSlice();
                defer allocator.free(right_slice);
                var right_primitives = std.ArrayList(BVHPrimitive).fromOwnedSlice(allocator, right_slice[mid..]);
                defer right_primitives.deinit();

                // std.debug.print("LEFT {d} RIGHT {d}\n", .{ left_primitives.items.len, right_primitives.items.len });

                // Recursively build BVHs for children
                // TODO I could go for a parallel approach here, it's illustrated in the book
                const left = try buildRecursive(
                    allocator,
                    &left_primitives,
                    total_nodes,
                    ordered_prims_offset,
                    ordered_prims,
                    primitives,
                    split_method,
                    max_prims_in_node,
                    transforms,
                );
                const right = try buildRecursive(
                    allocator,
                    &right_primitives,
                    total_nodes,
                    ordered_prims_offset,
                    ordered_prims,
                    primitives,
                    split_method,
                    max_prims_in_node,
                    transforms,
                );

                node.initInterior(dim, left, right);
            }
        }

        return node;
    }

    // NOTE: both these approaches apparently give the same end result visually.
    pub fn splitMiddle(allocator: std.mem.Allocator, centroid_bounds: Aabb, dim: usize, bvh_primitives: *std.ArrayList(BVHPrimitive)) !usize {
        // Partition primitives through node's midpoint
        const p_mid = (centroid_bounds.min[dim] + centroid_bounds.max[dim]) / 2.0;
        // std.sort.heap(BVHPrimitive, bvh_primitives.items, dim, boxCompare);
        // var turn_point: usize = 0;
        // for (bvh_primitives.items, 0..) |p, i| {
        //     if (p.centroid[dim] >= p_mid) {
        //         turn_point = i;
        //     }
        // }
        // // TODO this was mid_iter - bvh_primitives.begin()
        // // Maybe it's a way to cast to a number?
        // return turn_point;
        var left = std.ArrayList(BVHPrimitive).init(allocator);
        var right = std.ArrayList(BVHPrimitive).init(allocator);
        defer left.deinit();
        defer right.deinit();

        for (bvh_primitives.items) |p| {
            if (p.centroid[dim] >= p_mid) {
                try right.append(p);
            } else {
                try left.append(p);
            }
        }

        const mid = left.items.len;
        try bvh_primitives.replaceRange(0, left.items.len, left.items);
        try bvh_primitives.replaceRange(left.items.len, right.items.len, right.items);
        return mid;
    }

    pub fn splitEqualCounts(bvh_primitives: *std.ArrayList(BVHPrimitive)) usize {
        const mid = bvh_primitives.items.len / 2;
        // nth_element
        // first, last is the range
        // nth defines the sort partition point
        // policy execution policy
        // comp true if a < b
        // TODO
        // nthElement(bvh_primitives);

        return mid;
    }

    pub fn flattenBVH(node: *BVHBuildNode, offset: *usize, linear_nodes: *std.ArrayList(Aabb_GPU)) !usize {
        var linear_node = &linear_nodes.items[offset.*];
        linear_node.* = Aabb_GPU{};
        linear_node.min = zm.vecToArr3(node.bounds.min);
        linear_node.max = zm.vecToArr3(node.bounds.max);
        const node_offset: usize = offset.*;
        offset.* += 1;

        if (node.n_primitives > 0) {
            linear_node.primitive_offset = @intCast(node.first_prim_offset);
            linear_node.n_primitives = node.n_primitives;
        } else {
            // Create interior flattened BVH node
            linear_node.axis = @intCast(node.split_axis);
            linear_node.n_primitives = 0;
            if (node.left) |left| {
                _ = try flattenBVH(left, offset, linear_nodes);
            }
            if (node.right) |right| {
                linear_node.second_child_offset = @intCast(try flattenBVH(right, offset, linear_nodes));
            }
        }
        return node_offset;
    }
};

pub fn printLinearNodes(linear_nodes: []Aabb_GPU) void {
    std.debug.print("\n\n{d} LINEAR NODES:\n", .{linear_nodes.len});
    for (linear_nodes, 0..) |node, i| {
        if (node.primitive_offset == -1) {
            std.debug.print("NODE {d}, AXIS {d}, RIGHT {d} - [{d} {d} {d}] [{d} {d} {d}]\n", .{
                i,
                node.axis,
                node.second_child_offset,
                node.min[0],
                node.min[1],
                node.min[2],
                node.max[0],
                node.max[1],
                node.max[2],
            });
        } else {
            std.debug.print("LEAF {d}, PRIM OFF {d}, PRIM COUNT {d} - [{d} {d} {d}] [{d} {d} {d}]\n", .{
                i,
                node.primitive_offset,
                node.n_primitives,
                node.min[0],
                node.min[1],
                node.min[2],
                node.max[0],
                node.max[1],
                node.max[2],
            });
        }
    }
}

fn printTree(node: *BVHBuildNode) void {
    if (node.n_primitives == 0) {
        std.debug.print("\nTREE NODE\n", .{});
        if (node.left) |left| {
            printTree(left);
        } else {
            std.debug.print("LEFT NULL\n", .{});
        }
        if (node.right) |right| {
            printTree(right);
        } else {
            std.debug.print("RIGHT NULL\n", .{});
        }
    } else {
        std.debug.print("\nTREE LEAF\n", .{});
        std.debug.print("PRIM OFFSET {d}, PRIM COUNT {d}\n", .{ node.first_prim_offset, node.n_primitives });
    }
}

pub const CompareBucketContext = struct {
    n_buckets: f32,
    dim: usize,
    min_cost_split_bucket: i32,
    centroid_bounds: Aabb,
};

pub fn comparePrimToBuckets(
    // context: struct { comptime n_buckets: comptime_int = 12, dim: usize, min_cost_split_bucket: i32 },
    context: CompareBucketContext,
    prim: BVHPrimitive,
) bool {
    const min_cost: f32 = @floatFromInt(context.min_cost_split_bucket);
    const b = context.n_buckets * context.centroid_bounds.offset(prim.centroid)[context.dim];
    // std.debug.print("n {d} b_off {d} b {d}\n", .{ context.n_buckets, context.centroid_bounds.offset(prim.centroid)[context.dim], b });
    return b <= min_cost;
}

// NOTE: tentative implementation of c++ partition. I can probably improve it.
// I think this works fine, maybe I should find a better way to handle the context,
// like std functions do.
pub fn partitionArrayList(
    comptime T: type,
    array: *std.ArrayList(T),
    context: anytype,
    comptime predicate: fn (@TypeOf(context), item: T) bool,
) usize {
    var i: usize = 0;
    var j: usize = array.items.len;
    while (i < j) {
        while (i < j and predicate(context, array.items[i])) {
            i += 1;
        }
        while (i < j and !predicate(context, array.items[j - 1])) {
            j -= 1;
        }
        if (i < j) {
            // TODO with this, it doesn't work. But it should be here, RIGHT?
            // std.mem.swap(T, &array.items[i], &array.items[j - 1]);
            i += 1;
            j -= 1;
        }
    }
    return i;
}

const NthContext = struct {
    pivot_el_centroid: f32,
    dim: usize,
};

pub fn nthCompare(context: NthContext, prim: BVHPrimitive) bool {
    return prim.centroid[context.dim] < context.pivot_el_centroid;
}

// NOTE: naive implementation, hoping it works.
// This is highly inefficient, just to get some output
pub fn nthElementPrimitives(
    array: *std.ArrayList(BVHPrimitive),
    n: usize,
    dim: usize,
) !void {
    const clone = try array.clone();
    defer clone.deinit();
    std.sort.heap(BVHPrimitive, clone.items, dim, boxCompare);
    const pivot_el = clone.items[n];

    const context = NthContext{ .pivot_el_centroid = pivot_el.centroid[dim], .dim = dim };

    _ = partitionArrayList(BVHPrimitive, array, context, nthCompare);
}

fn boxCompare(dim: usize, a: BVHPrimitive, b: BVHPrimitive) bool {
    return a.centroid[dim] < b.centroid[dim];
}

// test "bvh" {
//     const Scene = @import("scenes.zig").Scene;
//     const allocator = std.testing.allocator;

//     var scene = Scene.init(allocator);
//     // try scene.loadBasicScene();
//     // try scene.loadTestScene(16);
//     try scene.loadWeekOneScene();
//     // _ = &scene;
//     defer scene.deinit();

//     try std.testing.expect(true);
// }

test "partitionArrayList" {
    const allocator = std.testing.allocator;
    const items: [8]i32 = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var array = std.ArrayList(i32).init(allocator);
    defer array.deinit();
    for (items) |i| {
        try array.append(i);
    }

    const Context = {};

    const Predicate = struct {
        fn predicate(_: @TypeOf(Context), n: i32) bool {
            return @rem(n, 2) == 0;
        }
    };

    const pivot = partitionArrayList(i32, &array, Context, Predicate.predicate);

    try std.testing.expect(pivot == 4);
}
