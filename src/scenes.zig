const std = @import("std");
const zm = @import("zmath");

const Material = @import("materials.zig").Material;
const Sphere = @import("objects.zig").Sphere;
const Vec = zm.Vec;

pub const Scene = struct {
    allocator: std.mem.Allocator,

    global_id: u32 = 0,
    spheres: std.ArrayList(Sphere),
    sphere_id: u32 = 0,
    materials: std.ArrayList(Material),
    material_id: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Scene {
        const spheres = std.ArrayList(Sphere).init(allocator);
        const materials = std.ArrayList(Material).init(allocator);
        return Scene{ .allocator = allocator, .spheres = spheres, .materials = materials };
    }

    pub fn deinit(self: *Scene) void {
        defer self.materials.deinit();
        defer self.spheres.deinit();
    }

    pub fn loadBasicScene(self: *Scene) !void {
        const red = Material.lambertian(.{ 1, 0, 0, 1 });
        const red_id = try self.addMaterial("red", red);
        const glass = Material.dielectric(.{ 1, 1, 1, 1 }, 1.6);
        const glass_id = try self.addMaterial("glass", glass);
        const b_glass = Material.dielectric(.{ 0.5, 0.5, 1, 1 }, 1.6);
        const b_glass_id = try self.addMaterial("glass", b_glass);
        const metal = Material.metal(.{ 0.2, 0.2, 0.2, 1 }, 0.8, 0.5);
        const metal_id = try self.addMaterial("metal", metal);
        const ground = Material.lambertian(.{ 0.1, 0.1, 0.1, 1 });
        const ground_id = try self.addMaterial("ground", ground);
        try self.addSphere(Vec{ 0, -100.5, -1, 0 }, 100, ground_id);
        try self.addSphere(Vec{ 0, 0, 0, 0 }, 0.5, red_id);
        try self.addSphere(Vec{ -1, 0, 0, 0 }, 0.5, metal_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.5, glass_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.25, b_glass_id);
    }

    fn addSphere(self: *Scene, center: Vec, radius: f32, material_id: u32) !void {
        const sphere = Sphere.init(center, radius, material_id);
        try self.spheres.append(sphere);

        self.sphere_id += 1;
        self.global_id += 1;
    }

    fn addMaterial(self: *Scene, label: []const u8, material: Material) !u32 {
        _ = label;
        const id = self.material_id;
        try self.materials.append(material);
        // try self.material_dict.put(label, &self.materials.items[id]);

        self.material_id += 1;

        return id;
    }
};
