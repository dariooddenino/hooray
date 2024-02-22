const std = @import("std");
const aabbs = @import("aabbs.zig");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");
const zm = @import("zmath");

const Aabb = aabbs.Aabb;
const Aabb_GPU = aabbs.Aabb_GPU;
const Object = @import("objects.zig").Object;
const Vec = @Vector(3, f32);

// Structure to build the array used for tree construction.
pub const BVHPrimitive = struct {
    primitive_index: usize,
    bounds: Aabb,

    pub fn centroid(self: BVHPrimitive) Vec {
        return (self.bounds.min + self.bounds.max) / zm.splat(Vec, 2.0);
    }
};

// Each represent a single node of the BVH tree
pub const BVHBuildNode = struct {
    // was bbox
    bounds: Aabb = Aabb{},
    // was axis
    split_axis: usize = 0,
    // I think this was start_id
    first_prim_offset: u16 = 0,
    // I think this was triangles
    n_primitives: u16 = 0,
    left: ?*BVHBuildNode = null,
    right: ?*BVHBuildNode = null,
    linear_node: Aabb_GPU = Aabb_GPU{}, // Part of the data is collected during tree building.

    // Build a leaf (no children)
    pub fn initLeaf(self: *BVHBuildNode, first: u16, n: usize, b: Aabb) void {
        self.first_prim_offset = first;
        self.n_primitives = @intCast(n);
        self.bounds = b;
        self.left = null;
        self.right = null;
    }

    // Build an interior node, assumes the two nodes have already been created.
    pub fn initInterior(self: *BVHBuildNode, axis: usize, c0: *BVHBuildNode, c1: *BVHBuildNode) void {
        self.left = c0;
        self.right = c1;
        self.bounds = Aabb.mergeBbox(c0.bounds, c1.bounds);
        self.split_axis = axis;
        self.n_primitives = 0;
    }

    pub fn getOffset(node: ?*BVHBuildNode) i32 {
        if (node == null) return -1;
        return node.?.first_prim_offset;
    }
};

pub const SplitMethod = enum { SAH, HLBVH, Middle, EqualCounts };

pub const BVHAggregate = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    max_prims_in_node: u32 = 0,
    primitives: []Object,
    linear_nodes: std.ArrayList(Aabb_GPU),
    split_method: SplitMethod,

    pub fn deinit(self: BVHAggregate) void {
        self.nodes.deinit();
        self.arena.deinit();
    }

    pub fn init(in_allocator: std.mem.Allocator, primitives: []Object, max_prims_in_node: usize, split_method: SplitMethod) !BVHAggregate {
        var arena = std.heap.ArenaAllocator.init(in_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Build the array of BVHPrimitive
        var bvh_primitives = std.ArrayList(BVHPrimitive).init(allocator);
        for (0..primitives.len) |i| {
            try bvh_primitives.append(BVHPrimitive{
                .primitive_index = i,
                .bounds = primitives[i].getBbox(),
            });
        }

        var root: *BVHBuildNode = undefined;
        // Build BVH for primitives
        var ordered_primitives = try std.ArrayList(Object).initCapacity(allocator, primitives.len);
        ordered_primitives.expandToCapacity();
        if (split_method == SplitMethod.HLBVH) {
            // TODO need to implement in the future.
            std.debug.print("HLBVH not implemented yet\n", .{});
            unreachable;
        } else {
            var ordered_prims_offset: u16 = 0;
            // TODO I think this was also reordering bvh_primitives.
            root = try buildRecursive(allocator, try bvh_primitives.toOwnedSlice(), &ordered_prims_offset, &ordered_primitives, primitives, split_method);
        }

        // TODO why is this needed and how to implement?
        // primitives.swap(ordered_primitives);

        // Convert BVH into compact representation in _nodes_ array
        // TODO no idea here
        // bvh_primitives.resize(0)
        // bvh_primitives.shrink_to_fit();

        var offset: usize = 0;
        populateLinks(root, null);

        var linear_nodes = try std.ArrayList(Aabb_GPU).initCapacity(allocator, primitives.len);
        linear_nodes.expandToCapacity();
        _ = try flattenBVH(root, &linear_nodes, &offset);

        return BVHAggregate{
            .arena = arena,
            .allocator = allocator,
            .max_prims_in_node = @intCast(max_prims_in_node),
            .primitives = primitives,
            .linear_nodes = linear_nodes,
            .split_method = split_method,
        };
    }

    /// Build the BVH tree recursively.
    pub fn buildRecursive(
        allocator: std.mem.Allocator,
        bvh_primitives: []BVHPrimitive, // Pre-prepared array of primitives
        ordered_prims_offset: *u16,
        ordered_prims: *std.ArrayList(Object), // Array of primitives reordered NOTE: should be empty, maybe not pass it from outside?
        primitives: []Object,
        split_method: SplitMethod,
    ) !*BVHBuildNode {
        // Compute bounds of all primitives in BVH node
        var bounds = Aabb{};
        for (bvh_primitives) |p| {
            bounds.merge(p.bounds);
        }

        var node = try allocator.create(BVHBuildNode);
        node.* = BVHBuildNode{};
        const surface_area = bounds.surfaceArea();
        // TODO inconsitency btw book and code
        // var axis: u32 = 0;
        // if (extent[1] > extent[0]) axis = 1;
        // if (extent[2] > extent[axis]) axis = 2;
        if (surface_area == 0 or bvh_primitives.len == 1) {
            // Create leaf
            const first_prim_offset = ordered_prims_offset.*;
            ordered_prims_offset.* += @intCast(bvh_primitives.len);

            for (0..bvh_primitives.len) |i| {
                const index = bvh_primitives[i].primitive_index;
                ordered_prims.items[first_prim_offset + i] = primitives[index];
            }
            node.initLeaf(first_prim_offset, bvh_primitives.len, bounds);
            return node;
        } else {
            // Compute bound of primitive centroids and choose split dimension _dim_
            var centroid_bounds = Aabb{};
            for (bvh_primitives) |p| {
                centroid_bounds.merge(p.bounds);
            }
            // TODO extend or centroid? Who knows
            const extent = centroid_bounds.extent();
            var dim: usize = 0;
            if (extent[1] > extent[0]) dim = 1;
            if (extent[2] > extent[dim]) dim = 2;

            // Partition primitives into two sets and build children
            if (centroid_bounds.max[dim] == centroid_bounds.min[dim]) {
                // Create leaf _BVHBuildNode_
                const first_prim_offset = ordered_prims_offset.*;
                ordered_prims_offset.* += @intCast(bvh_primitives.len);
                for (0..bvh_primitives.len) |i| {
                    const index = bvh_primitives[i].primitive_index;
                    ordered_prims.items[first_prim_offset + i] = primitives[index];
                }
                node.initLeaf(first_prim_offset, bvh_primitives.len, bounds);
                return node;
            } else {
                var mid = bvh_primitives.len / 2;
                // Partition primtives based on _splitMethod_
                switch (split_method) {
                    SplitMethod.Middle => {
                        // Partition primitives through node's midpoint
                        const p_mid = (centroid_bounds.min[dim] + centroid_bounds.max[dim]) / 2.0;
                        std.sort.heap(BVHPrimitive, bvh_primitives[0..], dim, boxCompare);
                        var turn_point: usize = 0;
                        for (bvh_primitives, 0..) |p, i| {
                            if (p.centroid()[dim] >= p_mid) {
                                turn_point = i;
                            }
                        }
                        // TODO this was mid_iter - bvh_primitives.begin()
                        // No idea of how c++ iterators work
                        mid = turn_point;
                        // TODO here there was a check to escape to EqualCounts in case of bad partitioning
                    },
                    SplitMethod.EqualCounts => {},
                    SplitMethod.SAH, SplitMethod.HLBVH => {},
                }

                // Recursively build BVHs for _children_
                const left = try buildRecursive(allocator, bvh_primitives[0..mid], ordered_prims_offset, ordered_prims, primitives, split_method);
                const right = try buildRecursive(allocator, bvh_primitives[mid..], ordered_prims_offset, ordered_prims, primitives, split_method);
                node.initInterior(dim, left, right);
            }
        }

        return node;
    }

    fn boxCompare(dim: usize, a: BVHPrimitive, b: BVHPrimitive) bool {
        return a.centroid()[dim] < b.centroid()[dim];
    }

    pub fn populateLinks(node: *BVHBuildNode, next_right_node: ?*BVHBuildNode) void {
        // If not leaf node
        // NOTE I wonder if this check is correct.
        if (node.left != null) {
            node.linear_node.hit_node = BVHBuildNode.getOffset(node.left);
            node.linear_node.miss_node = BVHBuildNode.getOffset(next_right_node);
            node.linear_node.right_offset = BVHBuildNode.getOffset(node.right);

            if (node.left) |left| {
                populateLinks(left, node.right);
            }
            if (node.right) |right| {
                populateLinks(right, next_right_node);
            }
        } else {
            node.linear_node.hit_node = BVHBuildNode.getOffset(next_right_node);
            node.linear_node.miss_node = node.linear_node.hit_node;
        }
    }

    // TODO VERY unsure here
    // Not sure of how I can get out of this mess.
    // I think I have to build the linear_node immediately and carry it around.
    // So that I can initialize some fields like in the original code.
    // Find where it was updated in the original code (I think when building the tree)
    pub fn flattenBVH(node: *BVHBuildNode, linear_nodes: *std.ArrayList(Aabb_GPU), offset: *usize) !usize {
        const node_offset = offset.*;

        // NOTE some of this stuff could be moved to node building?
        node.linear_node.mins = node.bounds.min;
        node.linear_node.maxs = node.bounds.max;
        node.linear_node.axis = @intCast(node.split_axis);

        if (node.n_primitives > 0) {
            node.linear_node.start_id = node.first_prim_offset;
            node.linear_node.tri_count = node.n_primitives;
            node.linear_node.hit_node = BVHBuildNode.getOffset(node.right); // TODO maybe??
            node.linear_node.miss_node = node.linear_node.hit_node; // original hit node
        } else {
            // Create interior flattened BVH node
            node.linear_node.axis = @intCast(node.split_axis);
            node.linear_node.tri_count = 0;
            node.linear_node.hit_node = BVHBuildNode.getOffset(node.left); // TODO maybe??
            node.linear_node.miss_node = BVHBuildNode.getOffset(node.right); // TODO maybe??
            if (node.left) |left| {
                _ = try flattenBVH(left, linear_nodes, offset);
            }
            if (node.right) |right| {
                node.linear_node.miss_node = @intCast(try flattenBVH(right, linear_nodes, offset));
            }
        }

        linear_nodes.items[node_offset] = node.linear_node;
        offset.* += 1;

        return node_offset;
    }
};
