const std = @import("std");
const zm = @import("zmath");
const vec = @import("vec.zig");
const utils = @import("utils.zig");

const Mat = zm.Mat;
const Vec = zm.Vec;
const Aabb = @import("aabbs.zig").Aabb;

/// A simple version for now. It just allows one translation and one rotation.
/// I will have to solve the "problem" that aabb are transformed for tree generation,
/// while the shapes maybe should be transformed in shaders.
pub const SimpleTransform = struct {
    offset: Vec = zm.splat(Vec, 0),
    sin_theta: f32 = 0,
    cos_theta: f32 = 1,

    pub inline fn label() ?[*:0]const u8 {
        return "SimpleTransform";
    }

    pub inline fn GpuType() type {
        return SimpleTransform_GPU;
    }

    pub fn init(offset: ?Vec, theta: ?f32) SimpleTransform {
        var self = SimpleTransform{};
        if (offset) |o| self.offset = o;
        if (theta) |t| {
            const t_rad = std.math.degreesToRadians(f32, t);
            self.sin_theta = @sin(t_rad);
            self.cos_theta = @cos(t_rad);
        }

        return self;
    }

    pub fn applyToBbox(self: SimpleTransform, in_bbox: Aabb) Aabb {
        var min: Vec = zm.splat(utils.infinity);
        var max: Vec = zm.splat(-utils.infinity);
        const bbox = in_bbox.add(self.offset);

        for (0..2) |i| {
            for (0..2) |j| {
                for (0..2) |k| {
                    const i_f: f32 = @floatFromInt(i);
                    const j_f: f32 = @floatFromInt(j);
                    const k_f: f32 = @floatFromInt(k);
                    const x = i_f * bbox.max[0] + (1 - i_f) * bbox.min[0];
                    const y = j_f * bbox.max[1] + (1 - j_f) * bbox.min[1];
                    const z = k_f * bbox.max[2] + (1 - k_f) * bbox.min[2];

                    const new_x = self.cos_theta * x + self.sin_theta * z;
                    const new_z = -self.sin_theta * x + self.cos_theta * z;

                    const tester = Vec{ new_x, y, new_z, 0 };

                    for (0..3) |c| {
                        min[c] = @min(min[c], tester[c]);
                        max[c] = @max(max[c], tester[c]);
                    }
                }
            }
        }

        return Aabb{ .min = min, .max = max };
    }

    pub const SimpleTransform_GPU = extern struct {
        offset: [3]f32,
        sin_theta: f32,
        cos_theta: f32,
        padding: [3]f32 = .{ 0, 0, 0 },
    };

    pub fn toGPU(allocator: std.mem.Allocator, transforms: std.ArrayList(SimpleTransform)) !std.ArrayList(SimpleTransform_GPU) {
        var transforms_gpu = std.ArrayList(SimpleTransform_GPU).init(allocator);
        for (transforms.items) |transform| {
            const transform_gpu = SimpleTransform_GPU{
                .offset = zm.vecToArr3(transform.offset),
                .sin_theta = transform.sin_theta,
                .cos_theta = transform.cos_theta,
            };
            try transforms_gpu.append(transform_gpu);
        }
        return transforms_gpu;
    }
};

// pub const Transform = struct {
//     model_matrix: Mat,
//     inv_model_matrix: Mat,

//     translateM: Mat,
//     translateV: Vec,
//     tx: f32,
//     ty: f32,
//     tz: f32,

//     scaleM: Mat,
//     scaleV: Vec,
//     sx: f32,
//     sy: f32,
//     sz: f32,

//     rotationM: Mat,
//     rotation_angle: f32,
//     rotation_axis: Vec,

//     pub inline fn label() ?[*:0]const u8 {
//         return "Transform";
//     }

//     pub inline fn GpuType() type {
//         return Transform_GPU();
//     }

//     pub const Transform_GPU = struct {
//         model_matrix: [16]f32,
//         inv_model_matrix: [16]f32,
//     };

//     pub fn init() Transform {
//         return Transform{
//             .model_matrix = zm.identity(),
//             .inv_model_matrix = zm.identity(),
//             .translateM = zm.splat(Mat, 0),
//             .translateV = zm.splat(Vec, 0),
//             .tx = 0,
//             .ty = 0,
//             .tz = 0,
//             .scaleM = zm.splat(Mat, 0),
//             .scaleV = zm.splat(Vec, 0),
//             .sx = 0,
//             .sy = 0,
//             .sz = 0,
//             .rotationM = zm.splat(Mat, 0),
//             .rotation_angle = 0,
//             .rotation_axis = Vec{ 1, 0, 0, 0 },
//         };
//     }

//     // TODO missing an update function, need to check what it does first.

//     pub fn translate(self: *Transform, x: f32, y: f32, z: f32) void {
//         self.tx = x;
//         self.ty = y;
//         self.tz = z;
//         self.translateV = Vec{ self.tx, self.ty, self.tz };
//         self.translateM = self.translateM.translationV(self.translateV);
//     }

//     pub fn scale(self: *Transform, sx: f32, sy: f32, sz: f32) void {
//         self.sx = sx;
//         self.sy = sy;
//         self.sz = sz;
//         self.scaleV = Vec{ sx, sy, sz, 0 };
//         self.scaleM = self.scaleM.scalingV(self.scaleV);
//     }

//     // NOTE I think this works only for one axis at a time
//     pub fn rotate(self: *Transform, theta: f32, axis: Vec) void {
//         self.rotation_angle = theta;
//         self.rotation_axis = axis;
//         // NOTE: this makes unbased assumptions on how this will be used.
//         if (axis[0] == 1) {
//             self.rotationM = self.rotationM.rotateX(theta);
//         }
//         if (axis[1] == 1) {
//             self.rotationM = self.rotationM.rotateY(theta);
//         }
//         if (axis[2] == 2) {
//             self.rotationM = self.rotationM.rotateZ(theta);
//         }
//     }
// };

pub const ObjectType = enum {
    sphere,
    quad,

    pub fn toType(self: ObjectType) i32 {
        switch (self) {
            .sphere => return 0,
            .quad => return 1,
        }
    }
};

pub const Object = union(enum) {
    sphere: Sphere,
    quad: Quad,

    pub inline fn label() ?[*:0]const u8 {
        return "Object";
    }

    pub inline fn GpuType() type {
        return Object_GPU;
    }

    pub const Object_GPU = extern struct {
        primitive_type: i32,
        primitive_id: u32,
    };

    pub fn getBbox(self: Object) Aabb {
        switch (self) {
            inline else => |o| return o.bbox,
        }
    }

    pub fn getType(self: Object) ObjectType {
        switch (self) {
            inline else => |o| return o.object_type,
        }
    }

    pub fn getLocalId(self: Object) u32 {
        switch (self) {
            inline else => |o| return o.local_id,
        }
    }

    pub fn toGPU(allocator: std.mem.Allocator, objects: std.ArrayList(Object)) !std.ArrayList(Object_GPU) {
        var objects_gpu = std.ArrayList(Object_GPU).init(allocator);
        for (objects.items) |object| {
            const object_gpu = Object_GPU{
                .primitive_type = object.getType().toType(),
                .primitive_id = object.getLocalId(),
            };
            try objects_gpu.append(object_gpu);
        }
        return objects_gpu;
    }
};

pub const Sphere = struct {
    object_type: ObjectType = .sphere,
    center: Vec,
    radius: f32,
    material_id: u32,
    local_id: u32, // Id in its own resource ArrayList
    bbox: Aabb,
    transform_id: ?u32 = null,

    pub inline fn label() ?[*:0]const u8 {
        return "Sphere";
    }

    pub inline fn GpuType() type {
        return Sphere_GPU;
    }

    pub fn init(center: Vec, radius: f32, material_id: u32, local_id: u32) Sphere {
        const bbox = Aabb.init(center - zm.splat(Vec, radius), center + zm.splat(Vec, radius));
        return Sphere{
            .center = center,
            .radius = radius,
            .material_id = material_id,
            .local_id = local_id,
            .bbox = bbox,
        };
    }

    pub fn addTransform(self: *Sphere, transform_id: u32) void {
        self.transform_id = transform_id;
    }

    pub const Sphere_GPU = extern struct {
        center: [3]f32,
        radius: f32,
        material_id: f32,
        transform_id: f32,
        padding: [2]f32 = .{ 0, 0 },
    };

    pub fn toGPU(allocator: std.mem.Allocator, spheres: std.ArrayList(Sphere)) !std.ArrayList(Sphere_GPU) {
        var spheres_gpu = std.ArrayList(Sphere_GPU).init(allocator);
        for (spheres.items) |sphere| {
            var transform_id: f32 = -1;
            if (sphere.transform_id) |t| {
                transform_id = @floatFromInt(t);
            }
            const sphere_gpu = Sphere_GPU{
                .center = zm.vecToArr3(sphere.center),
                .radius = sphere.radius,
                .material_id = @floatFromInt(sphere.material_id),
                .transform_id = transform_id,
            };
            try spheres_gpu.append(sphere_gpu);
        }
        return spheres_gpu;
    }
};

pub const Quad = struct {
    object_type: ObjectType = .quad,
    Q: Vec,
    u: Vec,
    v: Vec,
    material_id: u32,
    local_id: u32, // Id in its own resource ArrayList
    bbox: Aabb,
    normal: Vec,
    D: f32,
    w: Vec,
    transform_id: ?u32 = null,

    pub inline fn label() ?[*:0]const u8 {
        return "Quad";
    }

    pub inline fn GpuType() type {
        return Quad_GPU;
    }

    pub fn init(Q: Vec, u: Vec, v: Vec, material_id: u32, local_id: u32) Quad {
        var bbox = Aabb{ .min = Q, .max = Q + u + v };
        bbox.pad();
        const n = zm.cross3(u, v);
        const normal = zm.normalize3(n);
        const D = zm.dot3(normal, Q);
        const w = n / zm.dot3(n, n);
        return Quad{
            .Q = Q,
            .u = u,
            .v = v,
            .material_id = material_id,
            .local_id = local_id,
            .bbox = bbox,
            .normal = normal,
            .D = D[0],
            .w = w,
        };
    }

    pub fn addTransform(self: *Quad, transform_id: u32) void {
        self.transform_id = transform_id;
    }

    pub const Quad_GPU = extern struct {
        Q: [4]f32,
        u: [4]f32,
        v: [4]f32,
        w: [4]f32,
        normal: [4]f32,
        D: f32,
        material_id: f32,
        transform_id: f32,
        padding: [1]f32 = .{0},
        // padding0: f32 = 0,
        // padding1: f32 = 0,
        // padding2: f32 = 0,
        // padding1: f32 = 0,
        // padding: [3]f32 = .{ 0, 0, 0 },
    };

    pub fn toGPU(allocator: std.mem.Allocator, quads: std.ArrayList(Quad)) !std.ArrayList(Quad_GPU) {
        var quads_gpu = std.ArrayList(Quad_GPU).init(allocator);
        for (quads.items) |quad| {
            var transform_id: f32 = -1;
            if (quad.transform_id) |t| {
                transform_id = @floatFromInt(t);
            }
            const quad_gpu = Quad_GPU{
                .Q = zm.vecToArr4(quad.Q),
                .u = zm.vecToArr4(quad.u),
                .v = zm.vecToArr4(quad.v),
                .material_id = @floatFromInt(quad.material_id),
                .normal = zm.vecToArr4(quad.normal),
                .D = quad.D,
                .w = zm.vecToArr4(quad.w),
                .transform_id = transform_id,
            };
            try quads_gpu.append(quad_gpu);
        }
        return quads_gpu;
    }
};
