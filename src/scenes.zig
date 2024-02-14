const std = @import("std");
const zm = @import("zmath");

const Material = @import("materials.zig").Material;
const Sphere = @import("objects.zig").Sphere;

pub const Scene = struct {
    allocator: std.mem.Allocator,

    materials: std.ArrayList(Material),
    material_id: u32 = 0,
    material_dict: std.StringHashMap(*Material),

    global_id: u32 = 0,
    sphere_id: u32 = 0,
    spheres: std.ArrayList(Sphere),

    // TODO Objs I think it's a flat list of all objects.
    // I will get there once I know what to pass to the shaders.

    pub fn init(allocator: std.mem.Allocator) Scene {
        const materials = std.ArrayList(Material).init(allocator);
        const material_dict = std.StringHashMap(*Material).init(allocator);
        const spheres = std.ArrayList(Sphere).init(allocator);

        return Scene{
            .allocator = allocator,
            .materials = materials,
            .material_dict = material_dict,
            .spheres = spheres,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.materials.deinit();
        self.material_dict.deinit();
        self.spheres.deinit();
    }

    pub fn loadBasicScene(self: *Scene) void {
        const default_material = Material.init("default", 0, zm.loadArr3(.{ 1, 0, 0 }, zm.splat(0), zm.splat(0), 0, 0, 0));
        self.addMaterial(default_material);

        self.addSphere(zm.loadArr3(.{ -0.3, -0.65, 0.3 }), 0.35, default_material.material_id);
    }

    fn addSphere(self: *Scene, center: zm.Vector, radius: f32, material_id: u32) void {
        const sphere = Sphere.init(center, radius, self.global_id, self.sphere_id, self.materials.items[material_id]);
        self.spheres.append(sphere);

        self.sphere_id += 1;
        self.global_id += 1;
    }

    fn addMaterial(self: *Scene, material: Material) void {
        self.materials.append(material);
        self.material_dict.put(material.name, self.materials.items[self.material_id]);

        self.material_id += 1;
    }
};
