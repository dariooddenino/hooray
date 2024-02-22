const std = @import("std");
const utils = @import("utils.zig");
const zm = @import("zmath");

const Color = @Vector(3, f32);

pub const Material = extern struct {
    color: Color,
    specular_color: Color,
    emission_color: Color,
    specular_strength: f32,
    roughness: f32,
    eta: f32,
    material_type: u32,

    pub const Material_GPU = extern struct { color: Color, specular_color: Color, emission_color: Color, specular_strength: f32, roughness: f32, eta: f32, material_type: f32 };

    pub fn init(material_type: u32, color: Color, specular_color: Color, emission_color: Color, specular_strength: f32, roughness: f32, eta: f32) Material {
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

    pub fn toGPU(allocator: std.mem.Allocator, materials: std.ArrayList(Material)) !std.ArrayList(Material_GPU) {
        var materials_gpu = std.ArrayList(Material_GPU).init(allocator);
        for (materials.items) |material| {
            const material_gpu = Material_GPU{
                .color = material.color,
                .specular_color = material.specular_color,
                .emission_color = material.emission_color,
                .specular_strength = material.specular_strength,
                .roughness = material.roughness,
                .eta = material.eta,
                .material_type = @floatFromInt(material.material_type),
            };
            try materials_gpu.append(material_gpu);
        }

        return materials_gpu;
    }
};
