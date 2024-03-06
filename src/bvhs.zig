const std = @import("std");
const aabbs = @import("aabbs.zig");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");
const zm = @import("zmath");

const Aabb = aabbs.Aabb;
const Aabb_GPU = aabbs.Aabb_GPU;
const Object = @import("objects.zig").Object;
const ObjectType = @import("objects.zig").ObjectType;
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
    // was bbox
    bounds: Aabb = Aabb{},
    // was axis
    split_axis: usize = 0,
    left: ?*BVHBuildNode = null,
    right: ?*BVHBuildNode = null,
    // linear_node: Aabb_GPU = Aabb_GPU{}, // Part of the data is collected during tree building.
    // hit_node: i32 = -1,
    // miss_node: i32 = -1,
    // prim_type: i32 = -1,
    // prim_id: i32 = -1,
    first_prim_offset: u32 = 0,
    n_primitives: u32 = 0,

    // Build a leaf
    pub fn initLeaf(
        self: *BVHBuildNode,
        first: u32,
        n: usize,
        b: Aabb,
        // prim_type: i32,
        // prim_id: i32,
    ) void {
        self.first_prim_offset = first;
        self.n_primitives = @intCast(n);
        self.bounds = b;
        self.left = null;
        self.right = null;
        // self.prim_type = prim_type;
        // self.prim_id = prim_id;
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

    // pub fn getOffset(node: ?*BVHBuildNode) i32 {
    //     if (node == null) return -1;
    //     return node.?.first_prim_offset;
    // }
};

pub const SplitMethod = enum { SAH, HLBVH, Middle, EqualCounts };

pub const BVHAggregate = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    max_prims_in_node: u32 = 1,
    primitives: *[]Object,
    linear_nodes: std.ArrayList(Aabb_GPU),
    split_method: SplitMethod,

    pub fn deinit(self: BVHAggregate) void {
        self.nodes.deinit();
        self.arena.deinit();
    }

    pub fn init(
        in_allocator: std.mem.Allocator,
        primitives: *[]Object,
        split_method: SplitMethod,
    ) !BVHAggregate {
        var arena = std.heap.ArenaAllocator.init(in_allocator);
        const allocator = arena.allocator();

        const max_prims_in_node = 4;

        // Build the array of BVHPrimitive
        var bvh_primitives = std.ArrayList(BVHPrimitive).init(allocator);
        for (0..primitives.*.len) |i| {
            try bvh_primitives.append(BVHPrimitive.init(
                i,
                primitives.*[i].getType(),
                primitives.*[i].getLocalId(),
                primitives.*[i].getBbox(),
            ));
        }

        // Root node
        var root: *BVHBuildNode = undefined;
        // Primitives reordered for the BVH
        var ordered_primitives = try std.ArrayList(Object).initCapacity(allocator, primitives.*.len);
        ordered_primitives.expandToCapacity();
        var total_nodes: u32 = 0;

        std.debug.print("BUILDING BVH FOR {d} OBJECTS\n", .{primitives.*.len});
        const pre_build_t = std.time.microTimestamp();
        if (split_method == SplitMethod.HLBVH) {
            root = try buildHLBVH(allocator, bvh_primitives, &total_nodes, &ordered_primitives);
        } else {
            var ordered_prims_offset: u32 = 0;
            root = try buildRecursive(allocator, &bvh_primitives, &total_nodes, &ordered_prims_offset, &ordered_primitives, primitives.*, split_method, max_prims_in_node);
            // root = try buildRecursive(allocator, try bvh_primitives.toOwnedSlice(), &ordered_prims_offset, &ordered_primitives, primitives, split_method);
        }
        const post_build_t = std.time.microTimestamp();
        std.debug.print("BVH built in {d}us\n", .{post_build_t - pre_build_t});
        printTree(root);

        // TODO Not sure of this
        // primitives.swap(ordered_primitives);
        const ordered_slice = try ordered_primitives.toOwnedSlice();
        defer allocator.free(ordered_slice);
        primitives.* = ordered_slice;
        // std.mem.swap([]Object, primitives, &ordered_slice);

        // Convert BVH into compact representation in nodes array
        // Release bvh_primitives
        bvh_primitives.deinit();

        var linear_nodes = try std.ArrayList(Aabb_GPU).initCapacity(allocator, total_nodes);
        linear_nodes.expandToCapacity();
        var offset: usize = 0;
        const pre_flatten_t = std.time.microTimestamp();
        _ = try flattenBVH(root, &offset, &linear_nodes);
        const post_flatten_t = std.time.microTimestamp();
        std.debug.print("BVH flattened in {d}us\n", .{post_flatten_t - pre_flatten_t});
        printLinearNodes(linear_nodes.items);

        return BVHAggregate{
            .arena = arena,
            .allocator = allocator,
            .max_prims_in_node = max_prims_in_node,
            .primitives = primitives,
            .linear_nodes = linear_nodes,
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
    ) !*BVHBuildNode {
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

            // Partition primitives into two sets and build children
            if (centroid_bounds.max[dim] == centroid_bounds.min[dim]) {
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
                            // Partition primitives into equally sized subsets
                            mid = bvh_primitives.items.len / 2;
                            nthElement(bvh_primitives);
                        } else {
                            // Allocate _BVHSplitBucket_ for SAH partition buckets
                            const n_buckets = 12;
                            var buckets: [n_buckets]BVHSplitBucket = .{BVHSplitBucket{}} ** n_buckets;

                            // Initialize buckets for SAH partition
                            for (bvh_primitives.items) |prim| {
                                var b: usize = n_buckets * @as(usize, @intFromFloat(centroid_bounds.offset(prim.centroid)[dim]));
                                if (b == n_buckets) {
                                    b = n_buckets - 1;
                                }
                                buckets[b].count += 1;
                                buckets[b].bounds.merge(prim.bounds);
                            }

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
                            min_cost = 1 / (2 + min_cost / bounds.surfaceArea());

                            // Either create leaf or split primitives at selected SAH bucket
                            if (bvh_primitives.items.len > max_prims_in_node or min_cost < leaf_cost) {
                                var turn_point: u32 = 0;
                                for (bvh_primitives.items, 0..) |prim, j| {
                                    var b = n_buckets * centroid_bounds.offset(prim.centroid)[dim];
                                    if (b == n_buckets) {
                                        b = n_buckets - 1;
                                    }
                                    if (b > @as(f32, @floatFromInt(min_cost_split_bucket))) {
                                        turn_point = @intCast(j);
                                        break;
                                    }
                                }
                                mid = turn_point + 1;
                            } else {
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
                var left_slice = try left_clone.toOwnedSlice();
                defer allocator.free(left_slice);
                var left_primitives = std.ArrayList(BVHPrimitive).fromOwnedSlice(allocator, left_slice[0..mid]);
                defer left_primitives.deinit();

                var right_clone = try bvh_primitives.clone();
                var right_slice = try right_clone.toOwnedSlice();
                defer allocator.free(right_slice);
                var right_primitives = std.ArrayList(BVHPrimitive).fromOwnedSlice(allocator, right_slice[mid..]);
                defer right_primitives.deinit();

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
        nthElement(bvh_primitives);

        return mid;
    }

    // TODO this might be a problem source
    // I' must sorting it normally, I hope it's good enough  instead of nth_elment
    // Also dim is random...
    fn nthElement(bvh_primitives: *std.ArrayList(BVHPrimitive)) void {
        const dim: usize = 0;
        std.sort.heap(BVHPrimitive, bvh_primitives.items, dim, boxCompare);
    }

    /// Build the BVH tree recursively.
    // pub fn buildRecursives(
    //     allocator: std.mem.Allocator,
    //     bvh_primitives: []BVHPrimitive, // Pre-prepared array of primitives
    //     ordered_prims_offset: *u16,
    //     ordered_prims: *std.ArrayList(Object), // Array of primitives reordered NOTE: should be empty, maybe not pass it from outside?
    //     primitives: []Object,
    //     split_method: SplitMethod,
    // ) !*BVHBuildNode {
    //     // Compute bounds of all primitives in BVH node
    //     var bounds = Aabb{};
    //     for (bvh_primitives) |p| {
    //         bounds.merge(p.bounds);
    //     }

    //     var node = try allocator.create(BVHBuildNode);
    //     node.* = BVHBuildNode{};
    //     const surface_area = bounds.surfaceArea();
    //     // TODO inconsitency btw book and code
    //     // var axis: u32 = 0;
    //     // if (extent[1] > extent[0]) axis = 1;
    //     // if (extent[2] > extent[axis]) axis = 2;
    //     if (surface_area == 0 or bvh_primitives.len == 1) {
    //         // Create leaf
    //         const first_prim_offset = ordered_prims_offset.*;
    //         ordered_prims_offset.* += @intCast(bvh_primitives.len);

    //         for (0..bvh_primitives.len) |i| {
    //             const index = bvh_primitives[i].primitive_index;
    //             ordered_prims.items[first_prim_offset + i] = primitives[index];
    //         }
    //         node.initLeaf(first_prim_offset, bvh_primitives.len, bounds);
    //         return node;
    //     } else {
    //         // Compute bound of primitive centroids and choose split dimension _dim_
    //         var centroid_bounds = Aabb{};
    //         for (bvh_primitives) |p| {
    //             centroid_bounds.merge(p.bounds);
    //         }
    //         // TODO extend or centroid? Who knows
    //         const extent = centroid_bounds.extent();
    //         var dim: usize = 0;
    //         if (extent[1] > extent[0]) dim = 1;
    //         if (extent[2] > extent[dim]) dim = 2;

    //         // Partition primitives into two sets and build children
    //         if (centroid_bounds.max[dim] == centroid_bounds.min[dim]) {
    //             // Create leaf _BVHBuildNode_
    //             const first_prim_offset = ordered_prims_offset.*;
    //             ordered_prims_offset.* += @intCast(bvh_primitives.len);
    //             for (0..bvh_primitives.len) |i| {
    //                 const index = bvh_primitives[i].primitive_index;
    //                 ordered_prims.items[first_prim_offset + i] = primitives[index];
    //             }
    //             node.initLeaf(first_prim_offset, bvh_primitives.len, bounds);
    //             return node;
    //         } else {
    //             var mid = bvh_primitives.len / 2;
    //             // Partition primtives based on _splitMethod_
    //             switch (split_method) {
    //                 SplitMethod.Middle => {
    //                     // Partition primitives through node's midpoint
    //                     const p_mid = (centroid_bounds.min[dim] + centroid_bounds.max[dim]) / 2.0;
    //                     std.sort.heap(BVHPrimitive, bvh_primitives[0..], dim, boxCompare);
    //                     var turn_point: usize = 0;
    //                     for (bvh_primitives, 0..) |p, i| {
    //                         if (p.centroid()[dim] >= p_mid) {
    //                             turn_point = i;
    //                         }
    //                     }
    //                     // TODO this was mid_iter - bvh_primitives.begin()
    //                     // No idea of how c++ iterators work
    //                     mid = turn_point;
    //                     // TODO here there was a check to escape to EqualCounts in case of bad partitioning
    //                 },
    //                 SplitMethod.EqualCounts => {},
    //                 SplitMethod.SAH, SplitMethod.HLBVH => {},
    //             }

    //             // Recursively build BVHs for _children_
    //             const left = try buildRecursive(allocator, bvh_primitives[0..mid], ordered_prims_offset, ordered_prims, primitives, split_method);
    //             const right = try buildRecursive(allocator, bvh_primitives[mid..], ordered_prims_offset, ordered_prims, primitives, split_method);
    //             node.initInterior(dim, left, right);
    //         }
    //     }

    //     return node;
    // }

    fn boxCompare(dim: usize, a: BVHPrimitive, b: BVHPrimitive) bool {
        return a.centroid[dim] < b.centroid[dim];
    }

    pub fn flattenBVH(node: *BVHBuildNode, offset: *usize, linear_nodes: *std.ArrayList(Aabb_GPU)) !usize {
        var linear_node = &linear_nodes.items[offset.*];
        // TODO this was a tentative to see if it would help, probably useless.
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

fn printLinearNodes(linear_nodes: []Aabb_GPU) void {
    std.debug.print("LINEAR NODES:\n", .{});
    for (linear_nodes, 0..) |node, i| {
        if (node.primitive_offset == -1) {
            std.debug.print("NODE {d}, AXIS {d}, RIGHT {d}\n", .{ i, node.axis, node.second_child_offset });
        } else {
            std.debug.print("LEAF {d}, PRIM OFF {d}, PRIM COUNT {d}\n", .{ i, node.primitive_offset, node.n_primitives });
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
