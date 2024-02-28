fn hitScene(ray: Ray) -> bool {
    var closest_so_far = MAX_FLOAT;
    var hit_anything = false;

    for (var i = 0; i < NUM_SPHERES; i++) {
         if hitSphere(sphere_objs[i], ray_tmin, closest_so_far, ray) {
            hit_anything = true;
            closest_so_far = hit_rec.t;
        }
    }

    return hit_anything;
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

    // TODO material
    // hit_rec.material = materials[i32(sphere.material_id)];
    return true;
}