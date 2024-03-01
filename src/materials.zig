const std = @import("std");
const utils = @import("utils.zig");
const zm = @import("zmath");

const Color = zm.Vec;

pub const MaterialType = union(enum) {
    lambertian,
    // mirror,
    dielectric,
    // isotropic,
    // anisotropic,

    pub fn toType(self: MaterialType) u32 {
        switch (self) {
            .lambertian => return 0,
            // .mirror => return 1,
            .dielectric => return 2,
            // .isotropic => return 3,
            // .anisotropic => return 4,
        }
    }
};

pub const Material = extern struct {
    color: Color,
    specular_color: Color,
    emission_color: Color,
    specular_strength: f32,
    roughness: f32,
    eta: f32,
    material_type: MaterialType,

    pub const Material_GPU = extern struct {
        material_type: u32,
        specular_strength: f32,
        roughness: f32,
        eta: f32,
        color: @Vector(3, f32),
        specular_color: @Vector(3, f32),
        emission_color: @Vector(3, f32),
    };

    pub fn init(material_type: MaterialType, color: Color, specular_color: Color, emission_color: Color, specular_strength: f32, roughness: f32, eta: f32) Material {
        return Material{
            .material_type = material_type,
            .color = color,
            .specular_color = specular_color,
            .emission_color = emission_color,
            .specular_strength = specular_strength,
            .roughness = roughness,
            .eta = eta,
        };
    }

    pub fn lambertian(color: Color) Material {
        return Material.init(
            .lambertian,
            color,
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            0,
            1,
            0,
        );
    }

    pub fn metal(specular_color: Color, specular_strength: f32, roughness: f32) Material {
        return Material.init(
            .lambertian,
            .{ 0, 0, 0, 0 },
            specular_color,
            .{ 0, 0, 0, 0 },
            specular_strength,
            roughness,
            0,
        );
    }

    pub fn dielectric(color: Color, eta: f32) Material {
        return Material.init(
            .dielectric,
            color,
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            0,
            0,
            eta,
        );
    }

    pub fn toGPU(allocator: std.mem.Allocator, materials: std.ArrayList(Material)) !std.ArrayList(Material_GPU) {
        var materials_gpu = std.ArrayList(Material_GPU).init(allocator);
        for (materials.items) |material| {
            const material_gpu = Material_GPU{
                .color = .{ material.color[0], material.color[1], material.color[2] },
                .specular_color = .{ material.specular_color[0], material.specular_color[1], material.specular_color[2] },
                .emission_color = .{ material.emission_color[0], material.emission_color[1], material.emission_color[2] },
                .specular_strength = material.specular_strength,
                .roughness = material.roughness,
                .eta = material.eta,
                .material_type = material.material_type.toType(),
            };
            try materials_gpu.append(material_gpu);
        }

        return materials_gpu;
    }
};
