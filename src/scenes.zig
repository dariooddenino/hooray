const std = @import("std");
const zm = @import("zmath");

const Material = @import("materials.zig").Material;
const Object = @import("objects.zig").Object;
const Sphere = @import("objects.zig").Sphere;
const BVHTree = @import("bvhs.zig").BVHTree;

pub const Scene = struct {
    allocator: std.mem.Allocator,

    materials: std.ArrayList(Material),
    material_id: u32 = 0,
    material_dict: std.StringHashMap(*Material),

    global_id: u32 = 0,
    sphere_id: u32 = 0,
    spheres: std.ArrayList(Sphere),
    objects: std.ArrayList(Object),
    bvh: ?BVHTree = null,
    // flattened bvh?

    pub fn init(allocator: std.mem.Allocator) Scene {
        const materials = std.ArrayList(Material).init(allocator);
        const material_dict = std.StringHashMap(*Material).init(allocator);
        const spheres = std.ArrayList(Sphere).init(allocator);
        const objects = std.ArrayList(Object).init(allocator);

        return Scene{
            .allocator = allocator,
            .materials = materials,
            .material_dict = material_dict,
            .spheres = spheres,
            .objects = objects,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.materials.deinit();
        self.material_dict.deinit();
        if (self.bvh) |bvh| {
            bvh.deinit();
        }
        self.spheres.deinit();
        self.objects.deinit();
    }

    pub fn loadBasicScene(self: *Scene) void {
        const default_material = Material.init("default", 0, zm.loadArr3(.{ 1, 0, 0 }, zm.splat(0), zm.splat(0), 0, 0, 0));
        self.addMaterial(default_material);

        self.addSphere(zm.loadArr3(.{ -0.3, -0.65, 0.3 }), 0.35, default_material.material_id);

        self.createBVH();
    }

    fn createBVH(self: *Scene) void {
        // Take all the objects in a flat list
        // Pass them to the BVH builder
        // Get back a BVH
        const bvh = BVHTree.init(self.allocator, self.objects.items, 0, self.objects.items.len);
        self.bvh = bvh;
    }

    fn addSphere(self: *Scene, center: zm.Vector, radius: f32, material_id: u32) void {
        const sphere = Sphere.init(center, radius, self.global_id, self.sphere_id, self.materials.items[material_id]);
        self.spheres.append(sphere);
        self.objects.append(Object{ .sphere = sphere });

        self.sphere_id += 1;
        self.global_id += 1;
    }

    fn addMaterial(self: *Scene, material: Material) void {
        self.materials.append(material);
        self.material_dict.put(material.name, self.materials.items[self.material_id]);

        self.material_id += 1;
    }
};
