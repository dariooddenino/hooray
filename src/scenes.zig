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
const Camera = @import("camera.zig").Camera;
const Material = @import("materials.zig").Material;
const Object = @import("objects.zig").Object;
const Quad = @import("objects.zig").Quad;
const SimpleTransform = @import("objects.zig").SimpleTransform;
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
    transforms: std.ArrayList(SimpleTransform),
    transform_id: u32 = 0,
    bvh: BVHAggregate = undefined,
    bvh_array: std.ArrayList(Aabb_GPU),
    skyboxes: std.ArrayList(zstbi.Image),

    pub fn init(allocator: std.mem.Allocator) !Scene {
        const spheres = std.ArrayList(Sphere).init(allocator);
        const quads = std.ArrayList(Quad).init(allocator);
        const objects = std.ArrayList(Object).init(allocator);
        const materials = std.ArrayList(Material).init(allocator);
        const transforms = std.ArrayList(SimpleTransform).init(allocator);
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
            .transforms = transforms,
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
        defer self.transforms.deinit();
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

    pub fn loadBasicScene(self: *Scene, camera: *Camera) !void {
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
        try self.addQuad(Vec{ 20, -1, -20, 0 }, Vec{ -40, 0, 0, 0 }, Vec{ 0, 0, 40, 0 }, ground_id, null);
        // try self.addQuad(Vec{ -30, -0.5, -30, 0 }, Vec{ 60, 0, 0, 0 }, Vec{ 0, 0, 60, 0 }, ground_id);
        // try self.addQuad(Vec{ -30, -3, -30, 0 }, Vec{ 60, 0, 0, 0 }, Vec{ 0, 0, 60, 0 }, ground_id);
        // try self.addSphere(Vec{ 0, -100.5, 0, 0 }, 100, ground_id);
        try self.addSphere(Vec{ 0, 0, 0, 0 }, 0.5, red_id);
        try self.addSphere(Vec{ -1, 0, 0, 0 }, 0.5, metal_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.5, glass_id);
        try self.addSphere(Vec{ 1, 0, 0, 0 }, 0.25, b_glass_id);

        try self.createBVH();

        camera.setPosition(.{ -4, 4, 2, 0 });
    }

    pub fn loadWeekOneScene(self: *Scene, camera: *Camera) !void {
        const ground = Material.lambertian(.{ 0.5, 0.5, 0.5, 1 });
        const ground_id = try self.addMaterial("ground", ground);
        try self.addSphere(Vec{ 0, -301, 0, 0 }, 300, ground_id);

        const num_spheres = 11;

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

        camera.setPosition(.{ -4, 4, 2, 0 });
    }

    pub fn loadQuadsScene(self: *Scene, camera: *Camera) !void {
        const red = Material.lambertian(.{ 1, 0.2, 0.2, 0 });
        const red_id = try self.addMaterial("red", red);
        const green = Material.lambertian(.{ 0.2, 1, 0.2, 0 });
        const green_id = try self.addMaterial("green", green);
        const blue = Material.lambertian(.{ 0.2, 0.2, 1, 0 });
        const blue_id = try self.addMaterial("blue", blue);
        const orange = Material.diffuse_light(.{ 4, 4, 4, 0 });
        const orange_id = try self.addMaterial("orange", orange);
        const teal = Material.lambertian(.{ 0.2, 0.8, 0.8, 0 });
        const teal_id = try self.addMaterial("teal", teal);

        try self.addQuad(Vec{ -3, -2, 5, 0 }, Vec{ 0, 0, -4, 0 }, Vec{ 0, 4, 0, 0 }, red_id, null);
        try self.addQuad(Vec{ -2, -2, 0, 0 }, Vec{ 4, 0, 0, 0 }, Vec{ 0, 4, 0, 0 }, green_id, null);
        try self.addQuad(Vec{ 3, -2, 1, 0 }, Vec{ 0, 0, 4, 0 }, Vec{ 0, 4, 0, 0 }, blue_id, null);
        try self.addQuad(Vec{ -2, 3, 1, 0 }, Vec{ 4, 0, 0, 0 }, Vec{ 0, 0, 4, 0 }, orange_id, null);
        try self.addQuad(Vec{ -2, -3, 5, 0 }, Vec{ 4, 0, 0, 0 }, Vec{ 0, 0, -4, 0 }, teal_id, null);
        try self.addSphere(Vec{ 0, 0, 3, 0 }, 1, red_id);

        try self.createBVH();

        camera.setPosition(.{ 0, 0, 9, 0 });
    }

    // This scene is flipped backwards
    pub fn loadCornellScene(self: *Scene, camera: *Camera) !void {
        // const red = Material.lambertian(.{ 0.65, 0.05, 0.05, 0 });
        // const red_id = try self.addMaterial("red", red);
        const white = Material.lambertian(.{ 0.73, 0.73, 0.73, 0 });
        const white_id = try self.addMaterial("white", white);
        // const green = Material.lambertian(.{ 0.12, 0.45, 0.15, 0 });
        // const green_id = try self.addMaterial("green", green);
        // const light = Material.diffuse_light(.{ 15, 15, 15, 0 });
        // const light_id = try self.addMaterial("light", light);
        const fog = Material.isotropic(.{ 0.56, 0.29, 0.56, 1 }, 0.00001, 0.01, 0);
        const fog_id = try self.addMaterial("glass", fog);
        // const fog2 = Material.isotropic(.{ 0.56, 0.29, 0.56, 1 }, 0.00001, 5, 0);
        // const fog2_id = try self.addMaterial("glass", fog2);
        // const fog3 = Material.isotropic(.{ 0.56, 0.29, 0.56, 1 }, 0.00001, -5, 0);
        // const fog3_id = try self.addMaterial("glass", fog3);
        // const metal = Material.metal(.{ 0.73, 0.73, 0.73, 1 }, 1, 0.2);
        // const metal_id = try self.addMaterial("metal", metal);

        // left -200
        // try self.addQuad(Vec{ -200, 0, 200, 0 }, Vec{ 0, 0, -400, 0 }, Vec{ 0, 400, 0, 0 }, green_id, null);
        // right 200
        // try self.addQuad(Vec{ 200, 0, -200, 0 }, Vec{ 0, 0, 400, 0 }, Vec{ 0, 400, 0, 0 }, red_id, null);
        // light
        // try self.addQuad(Vec{ -50, 398, -50, 0 }, Vec{ 100, 0, 0, 0 }, Vec{ 0, 0, 100, 0 }, light_id, null);
        // top
        // try self.addQuad(Vec{ -200, 400, -200, 0 }, Vec{ 400, 0, 0, 0 }, Vec{ 0, 0, 400, 0 }, white_id, null);
        // bottom
        try self.addQuad(Vec{ -200, 0, 200, 0 }, Vec{ 400, 0, 0, 0 }, Vec{ 0, 0, -400, 0 }, white_id, null);
        // back
        // try self.addQuad(Vec{ -200, 0, 200, 0 }, Vec{ 0, 400, 0, 0 }, Vec{ 400, 0, 0, 0 }, white_id, null);
        try self.addSphere(Vec{ 80, 80, -70, 0 }, 60, fog_id);
        // try self.addSphere(Vec{ 80, 200, -70, 0 }, 60, fog2_id);
        // try self.addSphere(Vec{ 80, 320, -70, 0 }, 60, fog3_id);

        // const rotation1_id = try self.addTransform(SimpleTransform.init(null, 15));
        const rotation2_id = try self.addTransform(SimpleTransform.init(null, -18));
        // add box -200, 0, -200 | 200, 0, 200
        // min -200 0 -200
        // max 200 0 200
        // dx = Vec(max0 - min0, 0, 0) = Vec(400, 0, 0)
        // dy = Vec(0,0,max2 - min2) = Vec(0,0, 400)
        // top: addQuad(min0, max1, max2,,dx,,dz) == addQuad(Vec(-200, 0, 200), Vec(400, 0, 0), Vec(0, 0, 400))

        try self.addBox(Vec{ -50, 0, -80, 0 }, Vec{ -140, 90, -170, 0 }, white_id, rotation2_id);
        // try self.addBox(Vec{ 30, 0, 20, 0 }, Vec{ -80, 250, 150, 0 }, metal_id, rotation1_id);

        try self.createBVH();

        // camera.setPosition(.{ 0, 278, -600, 0 });
        camera.setCamera(.{ 0, 278, -400, 0 }, .{ 0, 200, 0, 0 }, .{ 0, 1, 0, 0 });
    }

    // Maybe carry objects slice around and defer it.
    pub fn createBVH(self: *Scene) !void {
        var objects_clone = try self.objects.clone();
        const objects_slice = try objects_clone.toOwnedSlice();
        defer self.allocator.free(objects_slice);
        const bvh = try bvhs.BVHAggregate.init(self.allocator, objects_slice, &self.transforms, bvhs.SplitMethod.SAH);
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

    fn addTransform(self: *Scene, transform: SimpleTransform) !u32 {
        try self.transforms.append(transform);
        defer self.transform_id += 1;
        return self.transform_id;
    }

    fn addSphere(self: *Scene, center: Vec, radius: f32, material_id: u32) !void {
        const sphere = Sphere.init(center, radius, material_id, self.sphere_id);
        try self.spheres.append(sphere);
        const object = Object{ .sphere = sphere };
        try self.objects.append(object);

        self.global_id += 1;
        self.sphere_id += 1;
    }

    fn addQuad(self: *Scene, Q: Vec, u: Vec, v: Vec, material_id: u32, transform_id: ?u32) !void {
        var quad = Quad.init(Q, u, v, material_id, self.quad_id);
        if (transform_id) |t_id| {
            quad.addTransform(t_id);
        }
        try self.quads.append(quad);
        const object = Object{ .quad = quad };
        try self.objects.append(object);

        self.global_id += 1;
        self.quad_id += 1;
    }

    fn addBox(scene: *Scene, a: Vec, b: Vec, material_id: u32, transform_id: ?u32) !void {
        const min = Vec{ @min(a[0], b[0]), @min(a[1], b[1]), @min(a[2], b[2]), 0 };
        const max = Vec{ @max(a[0], b[0]), @max(a[1], b[1]), @max(a[2], b[2]), 0 };

        const dx = Vec{ max[0] - min[0], 0, 0, 0 };
        const dy = Vec{ 0, max[1] - min[1], 0, 0 };
        // const dz = Vec{ 0, 0, max[2] - min[2], 0 };

        // try scene.addQuad(Vec{ min[0], min[1], max[2], 0 }, dx, dy, material_id, transform_id); // front
        // try scene.addQuad(Vec{ max[0], min[1], max[2], 0 }, -dz, dy, material_id, transform_id); // right
        try scene.addQuad(Vec{ min[0], max[1], min[2], 0 }, dx, -dy, material_id, transform_id); // back
        // try scene.addQuad(Vec{ min[0], min[1], min[2], 0 }, dz, dy, material_id, transform_id); // left
        // try scene.addQuad(Vec{ min[0], max[1], max[2], 0 }, dx, -dz, material_id, transform_id); // top
        // try scene.addQuad(Vec{ min[0], min[1], min[2], 0 }, dx, dz, material_id, transform_id); // bottom
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
