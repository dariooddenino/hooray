const std = @import("std");
const zm = @import("zmath");
const utils = @import("utils.zig");
const bvhs = @import("bvhs.zig");
const vec = @import("vec.zig");
const zstbi = @import("zstbi");

// TODO can I take it from the build file?
const content_dir = "skyboxes/";

const Aabb_GPU = @import("aabbs.zig").Aabb_GPU;
const BVHAggregate = @import("bvhs.zig").BVHAggregate;
const Material = @import("materials.zig").Material;
const Object = @import("objects.zig").Object;
const Quad = @import("objects.zig").Quad;
const Sphere = @import("objects.zig").Sphere;
const Vec = zm.Vec;

pub const Scene = struct {
    allocator: std.mem.Allocator,

    global_id: u32 = 0,
    objects: std.ArrayList(Object),
    spheres: std.ArrayList(Sphere),
    sphere_id: u32 = 0,
    quads: std.ArrayList(Quad),
    quad_id: u32 = 0,
    materials: std.ArrayList(Material),
    material_id: u32 = 0,
    bvh: BVHAggregate = undefined,
    bvh_array: std.ArrayList(Aabb_GPU),
    skyboxes: std.ArrayList(zstbi.Image),

    pub fn init(allocator: std.mem.Allocator) !Scene {
        const spheres = std.ArrayList(Sphere).init(allocator);
        const quads = std.ArrayList(Quad).init(allocator);
        const objects = std.ArrayList(Object).init(allocator);
        const materials = std.ArrayList(Material).init(allocator);
        const bvh_array = std.ArrayList(Aabb_GPU).init(allocator);
        var skyboxes = std.ArrayList(zstbi.Image).init(allocator);
        _ = &skyboxes;
        // try loadSkyboxes(allocator, &skyboxes);
        return Scene{
            .allocator = allocator,
            .objects = objects,
            .spheres = spheres,
            .quads = quads,
            .materials = materials,
            .bvh_array = bvh_array,
            .skyboxes = skyboxes,
        };
    }

    pub fn deinit(self: *Scene) void {
        // defer zstbi.deinit();
        defer self.materials.deinit();
        defer self.spheres.deinit();
        defer self.quads.deinit();
        defer self.objects.deinit();
        defer self.bvh.deinit();
        self.skyboxes.deinit();
    }

    pub fn loadTestScene(self: *Scene, n_sphere: usize) !void {
        const red = Material.lambertian(.{ 1, 0, 0, 1 });
        const red_id = try self.addMaterial("red", red);
        try self.addSphere(Vec{ 0, 0, 0, 0 }, 0.5, red_id);
        const deg: f32 = std.math.degreesToRadians(f32, @floatFromInt(360 / n_sphere));
        for (0..n_sphere) |n| {
            try self.addSphere(Vec{ 3 * @cos(@as(f32, @floatFromInt(n)) * deg), 0, 3 * @sin(@as(f32, @floatFromInt(n)) * deg), 0 }, 0.5, red_id);
        }

        try self.createBVH();
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
        try self.addSphere(Vec{ 0, -100.5, 0, 0 }, 100, ground_id);
        try self.addSphere(Vec{ 0, 0, 0, 0 }, 0.5, red_id);
        try self.addSphere(Vec{ -1, 0, 0, 0 }, 0.5, metal_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.5, glass_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.25, b_glass_id);

        try self.createBVH();
    }

    pub fn loadWeekOneScene(self: *Scene) !void {
        const ground = Material.lambertian(.{ 0.5, 0.5, 0.5, 1 });
        const ground_id = try self.addMaterial("ground", ground);
        try self.addSphere(Vec{ 0, -301, 0, 0 }, 300, ground_id);

        const num_spheres = 50;

        var a: f32 = -num_spheres;
        while (a < num_spheres) : (a += 1) {
            var b: f32 = -num_spheres;
            while (b < num_spheres) : (b += 1) {
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
        const b_glass = Material.dielectric(.{ 0.5, 0.5, 1, 1 }, 1.6);
        const b_glass_id = try self.addMaterial("glass", b_glass);
        const metal = Material.metal(.{ 0.2, 0.2, 0.2, 1 }, 0.8, 0.5);
        const metal_id = try self.addMaterial("metal", metal);

        try self.addSphere(Vec{ 0, 0, 0, 0 }, 1, red_id);
        try self.addSphere(Vec{ -4, 0, 0, 0 }, 1, metal_id);
        try self.addSphere(Vec{ 4, 0, 0, 0 }, 1, glass_id);
        try self.addSphere(Vec{ 4, 0, 0, 0 }, 0.25, b_glass_id);

        try self.createBVH();
    }

    pub fn loadQuadsScene(self: *Scene) !void {
        const red = Material.lambertian(.{ 1, 0.2, 0.2, 0 });
        const red_id = try self.addMaterial("red", red);
        // const green = Material.lambertian(.{0.2, 1, 0.2, 0});
        // const green_id = try self.addMaterial("green", green);
        // const blue = Material.lambertian(.{0.2, 0.2, 1, 0});
        // const blue_id = try self.addMaterial("blue", blue);
        // const orange = Material.lambertian(.{1, 0.5, 0, 0});
        // const orange_id = try self.addMaterial("orange", orange);
        // const teal = Material.lambertian(.{0.2, 0.8, 0.8});
        // const teal_id = try self.addMaterial("teal", teal);

        try self.addQuad(Vec{ -3, -2, -5, 0 }, Vec{ 0, 0, -4, 0 }, Vec{ 0, 4, 0, 0 }, red_id);

        try self.createBVH();
    }

    // TODO I have to study how clone() works, because I'm leaking here.
    // Maybe carry objects slice around and defer it.
    pub fn createBVH(self: *Scene) !void {
        var objects_clone = try self.objects.clone();
        const objects_slice = try objects_clone.toOwnedSlice();
        defer self.allocator.free(objects_slice);
        const bvh = try bvhs.BVHAggregate.init(self.allocator, objects_slice, bvhs.SplitMethod.SAH);
        self.bvh = bvh;
        self.bvh_array = bvh.linear_nodes;
    }

    inline fn loadSkyboxes(allocator: std.mem.Allocator, skyboxes: *std.ArrayList(zstbi.Image)) !void {
        _ = allocator;
        _ = skyboxes;
        // zstbi.init(allocator);
        // const files: [6][]const u8 = comptime .{
        //     "alps_field_2k.hdr",
        //     "autumn_park_2k.hdr",
        //     "kiara_9_dusk_2k.hdr",
        //     "rooitou_park_2k.hdr",
        //     "studio_small_03_2k.hdr",
        //     "studio_small_08_4k.hdr",
        // };

        // inline for (files) |file| {
        //     const skybox = try zstbi.Image.loadFromFile(content_dir ++ file, 4);
        //     try skyboxes.append(skybox);
        // }
    }

    fn addSphere(self: *Scene, center: Vec, radius: f32, material_id: u32) !void {
        const sphere = Sphere.init(center, radius, material_id, self.sphere_id);
        try self.spheres.append(sphere);
        const object = Object{ .sphere = sphere };
        try self.objects.append(object);

        self.global_id += 1;
        self.sphere_id += 1;
    }

    fn addQuad(self: *Scene, Q: Vec, u: Vec, v: Vec, material_id: u32) !void {
        const quad = Quad.init(Q, u, v, material_id, self.quad_id);
        try self.quads.append(quad);
        const object = Object{ .quad = quad };
        try self.objects.append(object);

        self.global_id += 1;
        self.quad_id += 1;
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
