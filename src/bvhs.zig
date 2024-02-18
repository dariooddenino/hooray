const std = @import("std");
const aabbs = @import("aabbs.zig");
const intervals = @import("intervals.zig");
const utils = @import("utils.zig");

const Aabb = aabbs.Aabb;
const Aabb_GPU = aabbs.Aabb_GPU;
const Object = @import("objects.zig").Object;
const Vec = @Vector(3, f32);

// Structure to build the array used for tree construction.
pub const BVHPrimitive = struct {
    primitive_index: usize,
    bounds: Aabb,

    pub fn centroid(self: BVHPrimitive) Vec {
        return (self.bounds.min + self.bounds.max) / 2.0;
    }
};

// Each represent a single node of the BVH tree
pub const BVHBuildNode = struct {
    // was bbox
    bounds: Aabb = Aabb{},
    // was axis
    split_axis: u32 = 0,
    // I think this was start_id
    first_prim_offset: u32 = 0,
    // I think this was triangles
    n_primitives: u32 = 0,
    left: ?*BVHBuildNode = null,
    right: ?*BVHBuildNode = null,

    // Build a leaf (no children)
    pub fn initLeaf(self: *BVHBuildNode, first: u32, n: u32, b: Aabb) void {
        self.first_prim_offset = first;
        self.n_primitives = n;
        self.bounds = b;
        self.left = null;
        self.right = null;
    }

    // Build an interior node, assumes the two nodes have already been created.
    pub fn initInterior(self: *BVHBuildNode, axis: u32, c0: *BVHBuildNode, c1: *BVHBuildNode) void {
        self.left = c0;
        self.right = c1;
        self.bounds = Aabb.mergeBbox(c0.bounds, c1.bounds);
        self.split_axis = axis;
        self.n_primitives = 0;
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

    pub fn init(in_allocator: std.mem.Allocator, primitives: []Object, max_prims_in_node: u32, split_method: SplitMethod) BVHAggregate {
        var arena = std.heap.ArenaAllocator.init(in_allocator);
        defer arena.deinit();
        const allocator = arena.allocator;
        var linear_nodes = std.ArrayList(Aabb_GPU).init(allocator);

        // Build the array of BVHPrimitive
        var bvh_primitives = std.ArrayList(BVHPrimitive).init(allocator);
        for (0..primitives.len) |i| {
            bvh_primitives.append(BVHPrimitive{
                .primitive_index = i,
                .bounds = primitives[i].getBbox(),
            });
        }

        var root: *BVHBuildNode = undefined;
        // Build BVH for primitives
        var ordered_primitives = std.ArrayList(Object).init(allocator);
        if (split_method == SplitMethod.HLBVH) {
            // TODO need to implement in the future.
            std.debug.print("HLBVH not implemented yet\n", .{});
            unreachable;
        } else {
            var ordered_prims_offset: u32 = 0;
            root = try buildRecursive(allocator, bvh_primitives, &ordered_prims_offset, &ordered_primitives, primitives);
        }

        // TODO why is this needed and how to implement?
        // primitives.swap(ordered_primitives);

        // Convert BVH into compact representation in _nodes_ array
        // TODO no idea here
        // bvh_primitives.resize(0)
        // bvh_primitives.shrink_to_fit();

        var offset = 0;
        _ = flattenBVH(root, &linear_nodes, &offset);

        return BVHAggregate{
            .arena = arena,
            .allocator = allocator,
            .max_prims_in_node = max_prims_in_node,
            .primitives = primitives,
            .linear_nodes = linear_nodes,
            .split_method = split_method,
        };
    }

    /// Build the BVH tree recursively.
    pub fn buildRecursive(
        allocator: std.mem.Allocator,
        bvh_primitives: std.ArrayList(BVHPrimitive), // Pre-prepared array of primitives
        ordered_prims_offset: *u32,
        ordered_prims: []Object, // Array of primitives reordered NOTE: should be empty, maybe not pass it from outside?
        primitives: []Object,
    ) !*BVHBuildNode {
        // Compute bounds of all primitives in BVH node
        var bounds = Aabb{};
        for (bvh_primitives.items) |p| {
            bounds.merge(p.bounds);
        }

        var node = allocator.create(BVHBuildNode);
        node.* = BVHBuildNode{};
        const extent = bounds.extent();
        // var axis: u32 = 0;
        // if (extent[1] > extent[0]) axis = 1;
        // if (extent[2] > extent[axis]) axis = 2;
        if (extent == 0 or bvh_primitives.items.len == 1) {
            // Create leaf
            const first_prim_offset = ordered_prims_offset;
            ordered_prims_offset += bvh_primitives.items.len;

            for (0..bvh_primitives.items.len) |i| {
                const index = bvh_primitives.items[i].primitive_index;
                ordered_prims[first_prim_offset + i] = primitives[index];
            }
            node.initLeaf(first_prim_offset, bvh_primitives.items.len, bounds);
            return node;
        } else {
            // Compute bound of primitive centroids and choose split dimension _dim_
            // TODO implement here the simplest of the methods proposed.
        }

        return node;
    }

    pub fn flattenBVH(node: *BVHBuildNode, linear_nodes: *std.ArrayList(Aabb_GPU), offset: *usize) u32 {
        var linear_node = linear_nodes.items[offset.*];
        linear_node.bounds = node.bounds;
        const node_offset = offset.*;
        offset.* += 1;
        if (node.n_primitives > 0) {
            linear_node.primitives_offset = node.first_prim_offset;
            linear_node.n_primitives = node.n_primitives;
        } else {
            // Create interior flattened BVH node
            linear_node.axis = node.split_axis;
            linear_node.n_primitives = 0;
            if (node.left) |left| {
                _ = flattenBVH(left, linear_nodes, offset);
            }
            if (node.right) |right| {
                linear_node.second_child_offset = flattenBVH(right, linear_nodes, offset);
            }
        }
        return node_offset;
    }
};
