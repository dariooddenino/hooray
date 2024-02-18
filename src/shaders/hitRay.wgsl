fn hitScene(ray: Ray) -> bool {
    var closest_so_far = MAX_FLOAT;
    var hit_anything = false;

    for (var i = 0; i < NUM_SPHERES; i++) {
        let medium = materials[i32(sphere_objs[i].material_id)].material_type;
        if medium < ISOTROPIC {
            if hit_sphere(sphere_objs[i], ray_tmin, closest_so_far, ray) {
                hit_anything = true;
                closest_so_far = hitRec.t;
            }
        } else {
            if hit_volume(sphere_objs[i], ray_tmin, closest_so_far, ray) {
                hit_anything = true;
                closest_so_far = hitRec.t;
            }
        }

		// if(hit_sphere(sphere_objs[i], ray_tmin, closest_so_far, ray))
		// {
		// 	hit_anything = true;
		// 	closest_so_far = hitRec.t;
		// }
    }

    for (var i = 0; i < NUM_QUADS; i++) {
        if hit_quad(quad_objs[i], ray_tmin, closest_so_far, ray) {
            hit_anything = true;
            closest_so_far = hitRec.t;
        }
    }

	// traversing BVH using a stack implementation
	// https://pbr-book.org/3ed-2018/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies#CompactBVHForTraversal

    const leaf_node = 2;		// fix this hardcoding later
    var inv_dir = 1 / ray.dir;
    var to_visit_offset = 0;
    var cur_node_idx = 0;
    var node = bvh[cur_node_idx];

    while true {
        node = bvh[cur_node_idx];

        if hit_aabb(node, ray_tmin, closest_so_far, ray, inv_dir) {
            if i32(node.prim_type) == leaf_node {

                let start_prim = i32(node.prim_id);
                let count_prim = i32(node.prim_count);
                for (var j = 0; j < count_prim; j++) {
                    if hit_triangle(triangles[start_prim + j], ray_tmin, closest_so_far, ray) {
                        hit_anything = true;
                        closest_so_far = hit_rec.t;
                    }
                }

                if to_visit_offset == 0 {
					break;
                }
                to_visit_offset--;
                cur_node_idx = stack[to_visit_offset];
            } else {
                if ray.dir[i32(node.axis)] < 0 {
                    stack[to_visit_offset] = cur_node_idx + 1;
                    to_visit_offset++;
                    cur_node_idx = i32(node.right_offset);
                } else {
                    stack[to_visit_offset] = i32(node.right_offset);
                    to_visit_offset++;
                    cur_node_idx++;
                }
            }
        } else {
            if to_visit_offset == 0 {
				      break;
            }

            to_visit_offset--;
            cur_node_idx = stack[to_visit_offset];
        }

        if to_visit_Offset >= STACK_SIZE {
			    break;
        }
    }
    return hit_anything;
}
	
