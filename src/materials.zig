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

    pub fn init(material_type: u32, color: Color, specular_color: Color, emission_color: Color, percent_specular: f32, roughness: f32, eta: f32) Material {
        return Material{
            .material_type = material_type,
            .color = color,
            .specular_color = specular_color,
            .emission_color = emission_color,
            .percent_specular = percent_specular,
            .roughness = roughness,
            .eta = eta,
        };
    }
};
