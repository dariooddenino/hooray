const std = @import("std");
const zm = @import("zmath");
const bvhs = @import("bvhs.zig");

const Material = @import("materials.zig").Material;
const Object = @import("objects.zig").Object;
const Quad = @import("objects.zig").Quad;
const Sphere = @import("objects.zig").Sphere;
const Aabb_GPU = bvhs.Aabb_GPU;
const Vec = @Vector(3, f32);

// TODO I need to revise this
// TODO I dn't think lights were actually used
pub const Scene = struct {
    allocator: std.mem.Allocator,

    materials: std.ArrayList(Material),
    material_id: u32 = 0,
    material_dict: std.StringHashMap(*Material),

    global_id: u32 = 0,
    sphere_id: u32 = 0,
    quad_id: u32 = 0,
    spheres: std.ArrayList(Sphere),
    quads: std.ArrayList(Quad),
    objects: std.ArrayList(Object),
    // lights: std.ArrayList(Quad),
    // triangles: std.ArrayList(Object),
    bvh_array: std.ArrayList(Aabb_GPU),

    pub fn init(allocator: std.mem.Allocator) Scene {
        const materials = std.ArrayList(Material).init(allocator);
        const material_dict = std.StringHashMap(*Material).init(allocator);
        const spheres = std.ArrayList(Sphere).init(allocator);
        const quads = std.ArrayList(Quad).init(allocator);
        const objects = std.ArrayList(Object).init(allocator);
        // const lights = std.ArrayList(Quad).init(allocator);
        const bvh_array = std.ArrayList(Aabb_GPU).init(allocator);

        return Scene{
            .allocator = allocator,
            .materials = materials,
            .material_dict = material_dict,
            .spheres = spheres,
            .quads = quads,
            .objects = objects,
            // .lights = lights,
            .bvh_array = bvh_array,
        };
    }

    pub fn deinit(self: *Scene) void {
        _ = self;
        // self.materials.deinit();
        // self.material_dict.deinit();
        // self.spheres.deinit();
        // self.quads.deinit();
        // self.objects.deinit();
        // self.lights.deinit();
    }

    pub fn loadBasicScene(self: *Scene) !void {
        const default_material = Material.init(0, Vec{ 1, 0, 0 }, zm.splat(Vec, 0), zm.splat(Vec, 0), 0, 0, 0);
        const default_material_id = try self.addMaterial("default", default_material);

        try self.addSphere(Vec{ -0.3, -0.65, 0.3 }, 0.35, default_material_id);

        const light_material = Material.init(0, zm.splat(Vec, 0), zm.splat(Vec, 0), zm.splat(Vec, 2), 0, 0, 0);
        const light_material_id = try self.addMaterial("light", light_material);

        try self.addQuad(Vec{ -1, 1, -1 }, Vec{ 3, 0, 0 }, Vec{ 0, 0, 2 }, light_material_id);

        try self.createBVH();
    }

    pub fn createBVH(self: *Scene) !void {
        // TODO Take all the triangles in a flat list. Why? what are these triangles? I think they are objects?
        // Call build_bvh, which I need to implement
        // the objs property goes into triangles
        // the flattened_array prop goes into bvh_array
        // let temp = [this.triangles].flat(); // TODO why?
        const bvh = try bvhs.buildBVH(self.allocator, self.objects, &self.bvh_array);
        defer bvh.deinit(self.allocator);
        // self.triangles = bvh.objs;
        // TODO I'm passing by reference...
        // self.bvh_array.* = bvh.flattened_array;
    }

    fn addSphere(self: *Scene, center: Vec, radius: f32, material_id: u32) !void {
        const sphere = Sphere.init(center, radius, self.global_id, self.sphere_id, material_id);
        try self.spheres.append(sphere);
        try self.objects.append(Object{ .sphere = sphere });

        self.sphere_id += 1;
        self.global_id += 1;
    }

    fn addQuad(self: *Scene, Q: Vec, u: Vec, v: Vec, material_id: u32) !void {
        const quad = Quad.init(Q, u, v, self.global_id, self.quad_id, material_id);
        try self.quads.append(quad);
        try self.objects.append(Object{ .quad = quad });

        self.quad_id += 1;
        self.global_id += 1;
    }

    fn addMaterial(self: *Scene, label: []const u8, material: Material) !u32 {
        const id = self.material_id;
        try self.materials.append(material);
        try self.material_dict.put(label, &self.materials.items[id]);

        self.material_id += 1;

        return id;
    }
};
