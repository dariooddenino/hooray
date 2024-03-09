@compute
@workgroup_size(64, 1, 1)
fn computeFrameBuffer(
    @builtin(workgroup_id) workgroup_id: vec3<u32>,
    @builtin(local_invocation_id) local_invocation_id: vec3<u32>,
    @builtin(local_invocation_index) local_invocation_index: u32,
    @builtin(num_workgroups) num_workgroups: vec3<u32>,
) {
    if (uniforms.rendering == 1) {
        let workgroup_index = workgroup_id.x + workgroup_id.y * num_workgroups.x + workgroup_id.z * num_workgroups.x * num_workgroups.y;
        let pixel_index = workgroup_index * 64 + local_invocation_index;		// global invocation index
        pixel_coords = vec3<f32>(f32(pixel_index) % f32(uniforms.target_dims.x), f32(pixel_index) / f32(uniforms.target_dims.x), 1);

        fov_factor = 1 / tan(60 * (PI / 180) / 2);
        cam_origin = uniforms.eye;

        NUM_SPHERES = i32(arrayLength(&sphere_objs));

        rand_state = pixel_index + u32(uniforms.frame_num) * 719393;

        // // get_lights();
        var path_traced_color = pathTrace();
        var frag_color = path_traced_color.xyz;

        // Progressive rendering with low samples
        if uniforms.reset_buffer == 0 {
            let weight = 1.0 / (uniforms.frame_num + 1);
            frag_color = framebuffer[pixel_index].xyz * (1 - weight) + path_traced_color * weight;
        }

        framebuffer[pixel_index] = vec4<f32>(frag_color.xyz, 1);

        // NOTE this is broken, AND I'd also have to update the framebuffer's size.
        // Calculate scale factor
        // let scaleFactorX = f32(uniforms.screen_dims.x) / f32(uniforms.target_dims.x);
        // let scaleFactorY = f32(uniforms.screen_dims.y) / f32(uniforms.target_dims.y);

        // // Calculate interpolated pixel coordinates
        // let interpX = pixel_coords.x * scaleFactorX;
        // let interpY = pixel_coords.y * scaleFactorY;

        // // Calculate the weights and contributions of neighboring pixels
        // var interpolatedColor = vec4<f32>(0, 0, 0, 0);
        // for (var i = -1; i <= 2; i++) {
        //     for (var j = -1; j <= 2; j++) {
        //         let neighborX = floor(interpX) + f32(i);
        //         let neighborY = floor(interpY) + f32(j);
        //         let weight = bicubicWeight(interpX - neighborX) * bicubicWeight(interpY - neighborY);
        //         let neighborPixelIndex = neighborY * f32(uniforms.target_dims.x) + neighborX;
        //         let neighborColor = getPixelColor(i32(neighborPixelIndex)); // Function to fetch pixel color
        //         interpolatedColor += neighborColor * vec4<f32>(weight);
        //     }
        // }

        // // Update framebuffer with interpolated color
        // framebuffer[pixel_index] = interpolatedColor;

    }
}

// // Bicubic weight function using the Mitchell-Netravali kernel
// fn bicubicWeight(x: f32) -> f32 {
//     // Mitchell-Netravali bicubic filter kernel constants
//     let B = 1.0 / 3.0;
//     let C = 1.0 / 3.0;

//     let x_abs = abs(x);
//     if (x_abs < 1.0) {
//         return ((12.0 - 9.0 * B - 6.0 * C) * x_abs * x_abs * x_abs +
//                 (-18.0 + 12.0 * B + 6.0 * C) * x_abs * x_abs +
//                 (6.0 - 2.0 * B)) / 6.0;
//     } else if (x_abs < 2.0) {
//         return ((-B - 6.0 * C) * x_abs * x_abs * x_abs +
//                 (6.0 * B + 30.0 * C) * x_abs * x_abs +
//                 (-12.0 * B - 48.0 * C) * x_abs +
//                 (8.0 * B + 24.0 * C)) / 6.0;
//     }
//     return 0.0;
// }

// // Function to fetch pixel color from the framebuffer
// fn getPixelColor(pixel_index: i32) -> vec4<f32> {
//     // Fetch and return the pixel color from the framebuffer
//     // You may need to handle boundary conditions and convert the index to integer
//     return framebuffer[pixel_index];
// }


// Paint a flat texture from the framebuffer

fn get1Dfrom2D(pos: vec2<f32>) -> u32 {
    return (u32(pos.y) * u32(uniforms.target_dims.x) + u32(pos.x));
}

@fragment
fn fs(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {

    let i = get1Dfrom2D(fragCoord.xy);
    // This makes it fade to black.
    // var color = framebuffer[i].xyz / uniforms.frame_num;
    var color = framebuffer[i].xyz;

    color = acesApprox(color.xyz);
    color = pow(color.xyz, vec3<f32>(1 / 2.2));

    // This gives an unpleasant black flicker
    // if uniforms.reset_buffer == 1 {
    //     framebuffer[i] = vec4<f32>(0);
    // }

    return vec4<f32>(color, 1);
}


struct Vertex {
	@location(0) position: vec2<f32>,
};

@vertex
fn vs(
    vert: Vertex
) -> @builtin(position) vec4<f32> {

    return vec4<f32>(vert.position, 0.0, 1.0);
}
