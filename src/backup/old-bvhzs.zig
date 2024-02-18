pub const BVHPair = struct {
    bvh: BVH,
    flattened_array: *std.ArrayList(Aabb_GPU),
};

// TODO This returns the BVH AND modifies the input array. I can't say I like this approach.aba
pub fn buildBVH(allocator: std.mem.Allocator, objects: std.ArrayList(Object), flattened_array: *std.ArrayList(Aabb_GPU)) !*BVH {
    var bvh = try BVH.createBVH(allocator, objects);
    // TODO not sure about this
    // TODO NEXT find how this is initialized
    try bvh.populateLinks(allocator, null);

    var flattened_id: usize = 0;

    try bvh.flatten(&flattened_id, flattened_array);

    return bvh;
}

// TODO why can't I just use a tree of ids?
// TODO I need a deinit here
pub const BVH = struct {
    left: ?*BVH = null,
    right: ?*BVH = null,
    bbox: Aabb = Aabb{},
    obj: ?Object = null,

    start_id: f32 = -1,
    tri_count: f32 = 0,

    id: f32 = -1,
    // These two hold the ids.
    hit_node: ?*BVH = null,
    miss_node: ?*BVH = null,
    right_offset: ?*BVH = null,

    axis: u32 = 0,

    pub fn deinit(self: *BVH, allocator: std.mem.Allocator) void {
        if (self.left) |left| {
            left.deinit(allocator);
        }
        if (self.right) |right| {
            right.deinit(allocator);
        }
        allocator.destroy(self);
    }

    fn createBVH(allocator: std.mem.Allocator, objects: std.ArrayList(Object)) !*BVH {
        return try generateBVHHierarchy(allocator, objects, 0, objects.items.len);
    }

    fn generateBVHHierarchy(allocator: std.mem.Allocator, objects: std.ArrayList(Object), start: usize, end: usize) !*BVH {
        var node = try allocator.create(BVH);
        node.* = BVH{};
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
        if (obj_span <= 1) {
            node.obj = objects.items[start];
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
            // TODO I think I have to allocate this?
            const left_node = try generateBVHHierarchy(allocator, objects, start, mid);
            const right_node = try generateBVHHierarchy(allocator, objects, mid, end);
            node.left = left_node;
            node.right = right_node;
            node.axis = axis;

            // TODO There has to be a better way to do this?
            // TODO does it even make sense to do it?
            // if (node.left) |left| {
            //     if (node.right) |right| {
            //         node.bbox.mergeBbox(left.bbox, right.bbox);
            //     } else {
            //         node.bbox = left.bbox;
            //     }
            // } else if (node.right) |right| {
            //     // Here left is null
            //     node.bbox = right.bbox;
            // }
        }
        return node;
    }

    pub fn populateLinks(self: *BVH, allocator: std.mem.Allocator, next_right_node: ?*BVH) !void {
        if (self.obj) |_| {
            self.hit_node = next_right_node;
            self.miss_node = self.hit_node;
        } else {
            self.hit_node = self.left;
            self.miss_node = next_right_node;
            // TODO https://pbr-book.org/3ed-2018/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies#CompactBVHForTraversal
            // I need to read this to see what this is actually doing
            self.right_offset = self.right;

            if (self.left) |_| {
                try self.left.?.populateLinks(allocator, self.right);
            }
            if (self.right) |_| {
                try self.right.?.populateLinks(allocator, next_right_node);
            }
        }
    }

    // TODO they were passing the flattened Aabbs
    fn flatten(self: *BVH, flattened_id: *usize, flattened_array: *std.ArrayList(Aabb_GPU)) !void {
        self.id = @floatFromInt(flattened_id.*);
        flattened_id.* += 1;

        // TODO It's passing the nullable object as it is, I'm assume it
        // uses the implicit casting to num??
        var right_offset: f32 = 0;
        if (self.right_offset) |_| {
            right_offset = 1;
        }
        // TODO idem
        var miss_node: f32 = -1;
        if (self.miss_node) |o| {
            miss_node = o.id;
        }

        var bbox = Aabb_GPU{
            .mins = self.bbox.min,
            .right_offset = right_offset,
            .maxs = self.bbox.max,
            .type = -1,
            .start_id = -1,
            .tri_count = -1,
            .miss_node = miss_node,
            .axis = @floatFromInt(self.axis),
        };
        if (self.obj) |obj| {
            bbox.type = obj.getType();
            bbox.start_id = self.start_id;
            bbox.tri_count = self.tri_count;
        }
        try flattened_array.append(bbox);

        if (self.left) |left| {
            try left.flatten(flattened_id, flattened_array);
        }
        if (self.right) |right| {
            try right.flatten(flattened_id, flattened_array);
        }
    }

    //
    pub fn boxCompare(axis_index: u32, a: Object, b: Object) bool {
        return a.getBbox().axis(axis_index)[0] < b.getBbox().axis(axis_index)[0];
    }

    // TODO Surface Area Heuristic
    pub fn generateBVHHierarchySAH() void {}

    pub fn evaluateSAH() void {}

    pub fn findBestSplitPlan() void {}
}