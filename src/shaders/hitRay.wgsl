fn hitScene(ray: Ray) -> bool {
    hit_rec.hit_bboxes = 0;
    var closest_so_far = MAX_FLOAT;
    var hit_anything = false;

    // for (var i = 0; i < NUM_SPHERES; i++) {
    //     if(hitSphere(sphere_objs[i], ray_tmin, closest_so_far, ray)) {
    //         hit_anything = true;
    //         closest_so_far = hit_rec.t;
    //     }
    // }

    // for (var i = 0; i < NUM_QUADS; i++) {
    //     if(hitQuad(quad_objs[i], ray_tmin, closest_so_far, ray)) {
    //         hit_anything = true;
    //         closest_so_far = hit_rec.t;
    //     }
    // }

    // return hit_anything;


    var inv_dir = 1 / ray.direction;

    var to_visit_offset = 0;
    var current_node_index = 0;

    while (true) {
        let node = bvh[current_node_index];

        if hitAabb(node, ray_tmin, closest_so_far, ray, inv_dir) {
            hit_rec.hit_bboxes++;
            if (node.n_primitives > 0) {
                for (var i = 0; i < i32(node.n_primitives); i++) {
                    var hit = false;
                    let object = objects[node.primitive_offset + i];
                    if (object.primitive_type == SPHERE) {
                        let sphere = sphere_objs[object.primitive_id];
                        hit = hitSphere(sphere, ray_tmin, closest_so_far, ray);
                    }
                    if (object.primitive_type == QUAD) {
                        let quad = quad_objs[object.primitive_id];
                        hit = hitQuad(quad, ray_tmin, closest_so_far, ray);
                    }
                    if (hit) {
                        hit_anything = true;
                        closest_so_far = hit_rec.t;
                    }
                }
                if (to_visit_offset == 0) {
                    break;
                }
                to_visit_offset--;
                current_node_index = nodes_to_visit[to_visit_offset];
            } else {
                if ray.direction[i32(node.axis)] < 0 {
                    nodes_to_visit[to_visit_offset] = current_node_index + 1;
                    to_visit_offset++;
                    current_node_index = node.second_child_offset;
                } else {
                    nodes_to_visit[to_visit_offset] = node.second_child_offset;
                    to_visit_offset++;
                    current_node_index++;
                }
            }
        } else {
            if to_visit_offset == 0 {
                break;
            }
            to_visit_offset--;
            // Retrieve the offset of the next node to visit
            current_node_index = nodes_to_visit[to_visit_offset];
        }

        if (to_visit_offset >= STACK_SIZE) {
            break;
        }
    }
    return hit_anything;
}


// https://medium.com/@bromanz/another-view-on-the-classic-ray-aabb-intersection-algorithm-for-bvh-traversal-41125138b525
fn hitAabb(box: AABB, tmin: f32, tmax: f32, ray: Ray, inv_dir: vec3<f32>) -> bool {
    var t0s = (box.min - ray.origin) * inv_dir;
    var t1s = (box.max - ray.origin) * inv_dir;

    var tsmaller = min(t0s, t1s);
    var tbigger = max(t0s, t1s);

    var t_min = max(tmin, max(tsmaller.x, max(tsmaller.y, tsmaller.z)));
    var t_max = min(tmax, min(tbigger.x, min(tbigger.y, tbigger.z)));

    return t_max > t_min;
}

fn hitSphere(sphere: Sphere, tmin: f32, tmax: f32, ray: Ray) -> bool {
    let center = sphere.center;
    let oc = ray.origin - center;
    let a = dot(ray.direction, ray.direction);
    let half_b = dot(oc, ray.direction);
    let c = dot(oc, oc) - sphere.radius * sphere.radius;
    let discriminant = half_b * half_b - a * c;

    if discriminant < 0 {
        return false;
    }

    let sqrtd = sqrt(discriminant);
    var root = (-half_b - sqrtd) / a;
    if root <= tmin || root >= tmax {
        root = (-half_b + sqrtd) / a;
        if root <= tmin || root >= tmax {
            return false;
        }
    }

    hit_rec.t = root;
    hit_rec.p = at(ray, root);

    hit_rec.normal = normalize((hit_rec.p - center) / sphere.radius);

    hit_rec.front_face = dot(ray.direction, hit_rec.normal) < 0;
    if !hit_rec.front_face {
        hit_rec.normal = -1 * hit_rec.normal;
    }

    hit_rec.material = materials[i32(sphere.material_id)];
    return true;
}

fn hitQuad(quad: Quad, tmin: f32, tmax: f32, ray: Ray) -> bool {
	if(dot(ray.direction, quad.normal) > 0) {
		return false;
	}

	let denom = dot(quad.normal, ray.direction);

	// No hit if the ray is paraller to the plane
	if(abs(denom) < 1e-8) {
		return false;
	}

	let t = (quad.D - dot(quad.normal, ray.origin)) / denom;
	if(t <= tmin || t >= tmax) {
		return false;
	}

	// determine if hit point lies within quarilateral
	let intersection = at(ray, t);

	let planar_hitpt_vector = intersection - quad.Q;
	let alpha = dot(quad.w, cross(planar_hitpt_vector, quad.v));
	let beta = dot(quad.w, cross(quad.u, planar_hitpt_vector));

	if(alpha < 0 || 1 < alpha || beta < 0 || 1 < beta) {
		return false;
	}

	hit_rec.t = t;
	hit_rec.p = intersection;
	hit_rec.normal = normalize(quad.normal);
	hit_rec.front_face = dot(ray.direction, hit_rec.normal) < 0;
	if(hit_rec.front_face == false)
	{
		hit_rec.normal = -hit_rec.normal;
	}

	hit_rec.material = materials[i32(quad.material_id)];
	return true;
}
