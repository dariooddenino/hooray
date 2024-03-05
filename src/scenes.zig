const std = @import("std");
const zm = @import("zmath");
const utils = @import("utils.zig");
const bvhs = @import("bvhs.zig");
const vec = @import("vec.zig");

const Aabb_GPU = @import("aabbs.zig").Aabb_GPU;
const Material = @import("materials.zig").Material;
const Object = @import("objects.zig").Object;
const Sphere = @import("objects.zig").Sphere;
const Vec = zm.Vec;

pub const Scene = struct {
    allocator: std.mem.Allocator,

    global_id: u32 = 0,
    objects: std.ArrayList(Object),
    spheres: std.ArrayList(Sphere),
    sphere_id: u32 = 0,
    materials: std.ArrayList(Material),
    material_id: u32 = 0,
    bvh_array: std.ArrayList(Aabb_GPU),

    pub fn init(allocator: std.mem.Allocator) Scene {
        const spheres = std.ArrayList(Sphere).init(allocator);
        const objects = std.ArrayList(Object).init(allocator);
        const materials = std.ArrayList(Material).init(allocator);
        const bvh_array = std.ArrayList(Aabb_GPU).init(allocator);
        return Scene{
            .allocator = allocator,
            .objects = objects,
            .spheres = spheres,
            .materials = materials,
            .bvh_array = bvh_array,
        };
    }

    pub fn deinit(self: *Scene) void {
        defer self.materials.deinit();
        defer self.spheres.deinit();
        defer self.objects.deinit();
        defer self.bvh_array.deinit();
    }

    pub fn loadBasicScene(self: *Scene) !void {
        const red = Material.lambertian(.{ 1, 0, 0, 1 });
        const red_id = try self.addMaterial("red", red);
        const glass = Material.dielectric(.{ 1, 1, 1, 1 }, 1.6);
        const glass_id = try self.addMaterial("glass", glass);
        // const b_glass = Material.dielectric(.{ 0.5, 0.5, 1, 1 }, 1.6);
        // const b_glass_id = try self.addMaterial("glass", b_glass);
        const metal = Material.metal(.{ 0.2, 0.2, 0.2, 1 }, 0.8, 0.5);
        const metal_id = try self.addMaterial("metal", metal);
        const ground = Material.lambertian(.{ 0.1, 0.1, 0.1, 1 });
        const ground_id = try self.addMaterial("ground", ground);
        try self.addSphere(Vec{ 0, -100.5, 0, 0 }, 100, ground_id);
        try self.addSphere(Vec{ 0, 0, 0, 0 }, 0.5, red_id);
        try self.addSphere(Vec{ -1, 0, 0, 0 }, 0.5, metal_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.5, glass_id);
        // try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.25, b_glass_id);

        try self.createBVH();
    }

    pub fn loadWeekOneScene(self: *Scene) !void {
        const ground = Material.lambertian(.{ 0.5, 0.5, 0.5, 1 });
        const ground_id = try self.addMaterial("ground", ground);
        try self.addSphere(Vec{ 0, -201, 0, 0 }, 200, ground_id);

        var a: f32 = -11;
        while (a < 11) : (a += 1) {
            var b: f32 = -11;
            while (b < 11) : (b += 1) {
                const choose_mat = utils.randomDouble();
                const center = Vec{ a + 0.9 * utils.randomDouble(), -0.8, b + 0.9 * utils.randomDouble(), 0 };

                // NOTE: this will break if I start using the material dictionary
                if (zm.length3(center - Vec{ 4, 0.2, 0, 0 })[0] > 0.9) {
                    if (choose_mat < 0.8) {
                        // diffuse
                        const albedo = vec.random() * vec.random();
                        const sphere_material = Material.lambertian(albedo);
                        const sphere_material_id = try self.addMaterial("", sphere_material);
                        try self.addSphere(center, 0.4 * choose_mat, sphere_material_id);
                    } else if (choose_mat < 0.95) {
                        // metal
                        const albedo = vec.randomRange(0.5, 1);
                        const specular = utils.randomDoubleRange(0.6, 1);
                        const fuzz = utils.randomDoubleRange(0, 0.5);

                        const sphere_material = Material.metal(albedo, specular, fuzz);
                        const sphere_material_id = try self.addMaterial("", sphere_material);
                        try self.addSphere(center, 0.5 * choose_mat, sphere_material_id);
                    } else {
                        // glass
                        const diel = utils.randomDoubleRange(1, 2);
                        const albedo = vec.randomRange(0.7, 1);
                        const sphere_material = Material.dielectric(albedo, diel);
                        const sphere_material_id = try self.addMaterial("", sphere_material);
                        try self.addSphere(center, 0.3 * choose_mat, sphere_material_id);
                    }
                }
            }
        }

        const red = Material.lambertian(.{ 0.4, 0.2, 0.1, 1 });
        const red_id = try self.addMaterial("red", red);
        const glass = Material.dielectric(.{ 1, 1, 1, 1 }, 1.6);
        const glass_id = try self.addMaterial("glass", glass);
        // const b_glass = Material.dielectric(.{ 0.5, 0.5, 1, 1 }, 1.6);
        // const b_glass_id = try self.addMaterial("glass", b_glass);
        const metal = Material.metal(.{ 0.2, 0.2, 0.2, 1 }, 0.8, 0.5);
        const metal_id = try self.addMaterial("metal", metal);

        try self.addSphere(Vec{ 0, 0, 0, 0 }, 1, red_id);
        try self.addSphere(Vec{ -4, 0, 0, 0 }, 1, metal_id);
        try self.addSphere(Vec{ 4, 0, 0, 0 }, 1, glass_id);
        // try self.addSphere(Vec{ 4, 0, 0, 0 }, 0.25, b_glass_id);

        try self.createBVH();
    }

    pub fn createBVH(self: *Scene) !void {
        var objects_clone = try self.objects.clone();
        var objects_slice = try objects_clone.toOwnedSlice();
        defer self.allocator.free(objects_slice);
        const bvh = try bvhs.BVHAggregate.init(self.allocator, &objects_slice, self.objects.items.len, bvhs.SplitMethod.Middle);
        self.bvh_array = bvh.linear_nodes;
    }

    fn addSphere(self: *Scene, center: Vec, radius: f32, material_id: u32) !void {
        const sphere = Sphere.init(center, radius, material_id, self.sphere_id);
        try self.spheres.append(sphere);
        const object = Object{ .sphere = sphere };
        try self.objects.append(object);

        self.global_id += 1;
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
