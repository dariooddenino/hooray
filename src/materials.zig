const std = @import("std");
const utils = @import("utils.zig");
const vec = @import("vec.zig");

const Color = vec.Color;

pub const Material = struct {
    albedo: Color,
    specular: Color,
    emission: Color,
    emission_strength: f32,
    roughness: f32,
    specular_highlight: f32,
    specular_exponent: f32,

    pub fn initAlbedo(albedo: Color) Material {
        return Material{
            .albedo = albedo,
            .specular = Color{ 0, 0, 0 },
            .emission = Color{ 0, 0, 0 },
            .emission_strength = 1,
            .roughness = 1,
            .specular_highlight = 0.0,
            .specular_exponent = 0.5,
        };
    }

    pub fn init(albedo: Color, specular: Color, emission: Color, emission_strength: f32, roughness: f32, specular_highlight: f32, specular_exponent: f32) Material {
        return Material{
            .albedo = albedo,
            .specular = specular,
            .emission = emission,
            .emission_strength = emission_strength,
            .roughness = roughness,
            .specular_highlight = specular_highlight,
            .specular_exponent = specular_exponent,
        };
    }
};
