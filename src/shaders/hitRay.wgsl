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

fn hitSphere(sphere: Sphere, tmin: f32, tmax: f32, in_ray: Ray) -> bool {
    var ray = in_ray;
    if (sphere.transform_id > -1) {
        let transform = transforms[i32(sphere.transform_id)];
        ray = Ray(in_ray.origin - transform.offset, in_ray.direction);
    }
    let material = materials[i32(sphere.material_id)];

    if (material.material_type == ISOTROPIC) {
        var rec1 = hitSphereLocal(sphere, -MAX_FLOAT, MAX_FLOAT, ray);
        if (rec1 == MAX_FLOAT + 1) {
            return false;
        }
        var rec2 = hitSphereLocal(sphere, rec1 + MIN_FLOAT, MAX_FLOAT, ray);
        if (rec2 == MAX_FLOAT + 1) {
            return false;
        }
        if (rec1 < tmin) {
            rec1 = tmin;
        }
        if (rec2 > tmax) {
            rec2 = tmax;
        }
        if (rec1 >= rec2) {
            return false;
        }
        if (rec1 < 0) {
            rec1 = 0;
        }
        hit_rec.material = materials[i32(sphere.material_id)];

        let ray_length = length(ray.direction);
        // let ray_length: f32 = 1;
        let dist_inside = (rec2 - rec1) * ray_length;
        let hit_dist = hit_rec.material.roughness * log(rand2D());

        if (hit_dist > dist_inside) {
            return false;
        }

        hit_rec.t = rec1 + (hit_dist / ray_length);
        hit_rec.p = at(ray, hit_rec.t);
        hit_rec.normal = normalize(hit_rec.p - sphere.center);
        hit_rec.front_face = true;

        return true;

    } else {
        let center = sphere.center;
        var root = hitSphereLocal(sphere, tmin, tmax, ray);
        if (root == MAX_FLOAT + 1) {
            return false;
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
}

// TODO aren't there better things than MAX_FLOAT?
fn hitSphereLocal(sphere: Sphere, tmin: f32, tmax: f32, ray: Ray) -> f32 {
    let center = sphere.center;
    let oc = ray.origin - center;
    let a = dot(ray.direction, ray.direction);
    let half_b = dot(oc, ray.direction);
    let c = dot(oc, oc) - sphere.radius * sphere.radius;
    let discriminant = half_b * half_b - a * c;

    if (discriminant < 0) {
        return MAX_FLOAT + 1;
    }

    let sqrtd = sqrt(discriminant);
    var root = (-half_b - sqrtd) / a;
    if root <= tmin || root >= tmax {
        root = (-half_b + sqrtd) / a;
        if root <= tmin || root >= tmax {
            return MAX_FLOAT + 1;
        }
    }

    return root;
}

fn hitQuad(quad: Quad, tmin: f32, tmax: f32, in_ray: Ray) -> bool {
    var ray = in_ray;
    if (quad.transform_id > -1) {
        let transform = transforms[i32(quad.transform_id)];
        var origin = in_ray.origin;
        var direction = in_ray.direction;
        // Translate
        origin -= transform.offset;
        // Rotate
        origin.x = transform.cos_theta * in_ray.origin.x - transform.sin_theta * in_ray.origin.z;
        origin.z = transform.sin_theta * in_ray.origin.x + transform.cos_theta * in_ray.origin.z;
        direction.x = transform.cos_theta * in_ray.direction.x - transform.sin_theta * in_ray.direction.z;
        direction.z = transform.sin_theta * in_ray.direction.x + transform.cos_theta * in_ray.direction.z;

        ray = Ray(origin, direction);

        if (!hitQuadInner(quad, tmin, tmax, ray)) {
            return false;
        }

        // Change the intersection point from object space to world space
        // TODO should I do the same for the translation offset?
        var p = hit_rec.p;
        p.x = transform.cos_theta * hit_rec.p.x + transform.sin_theta * hit_rec.p.z;
        p.z = -transform.sin_theta * hit_rec.p.x + transform.cos_theta * hit_rec.p.z;

        // Change the normal from object space to world space
        var normal = hit_rec.normal;
        normal.x = transform.cos_theta * hit_rec.normal.x + transform.sin_theta * hit_rec.normal.z;
        normal.z = -transform.sin_theta * hit_rec.normal.x + transform.cos_theta * hit_rec.normal.z;

        hit_rec.p = p;
        hit_rec.normal = normal;

        return true;
    }

    return hitQuadInner(quad, tmin, tmax, ray);
}

fn hitQuadInner(quad: Quad, tmin: f32, tmax: f32, ray: Ray) -> bool {
    let normal = quad.normal.xyz;
	if(dot(ray.direction, normal) > 0) {
		return false;
	}

	let denom = dot(normal, ray.direction);

	// No hit if the ray is paraller to the plane
	if(abs(denom) < 1e-8) {
		return false;
	}

	let t = (quad.D - dot(normal, ray.origin)) / denom;
	if(t <= tmin || t >= tmax) {
		return false;
	}

	// determine if hit point lies within quarilateral
	let intersection = at(ray, t);

	let planar_hitpt_vector = intersection - quad.Q.xyz;
	let alpha = dot(quad.w.xyz, cross(planar_hitpt_vector, quad.v.xyz));
	let beta = dot(quad.w.xyz, cross(quad.u.xyz, planar_hitpt_vector));

	if(alpha < 0 || 1 < alpha || beta < 0 || 1 < beta) {
		return false;
	}

	hit_rec.t = t;
	hit_rec.p = intersection;
	hit_rec.normal = normalize(normal);
	hit_rec.front_face = dot(ray.direction, hit_rec.normal) < 0;
	if(hit_rec.front_face == false)
	{
		hit_rec.normal = -hit_rec.normal;
	}

	hit_rec.material = materials[i32(quad.material_id)];
	return true;
}
