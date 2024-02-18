// ACES approximation for tone mapping
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/):
fn aces_approx(v: vec3f) -> vec3f {
    let v1 = v * 0.6f;
    const a = 2.51f;
    const b = 0.03f;
    const c = 2.43f;
    const d = 0.59f;
    const e = 0.14f;
    return clamp((v1 * (a * v1 + b)) / (v1 * (c * v1 + d) + e), vec3(0.0f), vec3(1.0f));
}

fn get_lights() -> bool {
    for (var i = 0; i < NUM_QUADS; i++) {
        let emission = materials[i32(quad_objs[i].material_id)].emission_color;

        if emission.x > 0.0 {
            lights = quad_objs[i];
			break;
        }
    }

    return true;
}