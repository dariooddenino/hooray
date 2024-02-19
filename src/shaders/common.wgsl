fn at(ray: Ray, t: f32) -> vec3f {
    return ray.origin + t * ray.dir;
}

// PCG prng
// https://www.shadertoy.com/view/XlGcRh
fn rand2D() -> f32 {
    rand_state = rand_state * 747796405u + 2891336453u;
    var word: u32 = ((rand_state >> ((rand_state >> 28u) + 4u)) ^ rand_state) * 277803737u;
    return f32((word >> 22u) ^ word) / 4294967295;
}

// random numbers from a normal distribution
fn randNormalDist() -> f32 {
    let theta = 2 * PI * rand2D();
    let rho = sqrt(-2 * log(rand2D()));
    return rho * cos(theta);
}

fn random_double(min: f32, max: f32) -> f32 {
    return min + (max - min) * rand2D();
}

fn near_zero(v: vec3f) -> bool {
    return (abs(v[0]) < 0 && abs(v[1]) < 0 && abs(v[2]) < 0);
}

fn hit_sphere(sphere: Sphere, tmin: f32, tmax: f32, ray: Ray) -> bool {
	
	// let ray = Ray((vec4f(incidentRay.origin, 1) * transforms[i32(sphere.id)].invModelMatrix).xyz, (vec4f(incidentRay.dir, 0) * transforms[i32(sphere.id)].invModelMatrix).xyz);

    let oc = ray.origin - sphere.center;
    let a = dot(ray.dir, ray.dir);
    let half_b = dot(ray.dir, oc);
    let c = dot(oc, oc) - sphere.r * sphere.r;
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

	// hitRec.p = (vec4f(hitRec.p, 1) * transforms[i32(sphere.id)].invModelMatrix).xyz;
	// hitRec.t = distance(hitRec.p, incidentRay.origin);

    hit_rec.normal = normalize((hit_rec.p - sphere.center) / sphere.r);

	// hitRec.normal = normalize((vec4f(hitRec.normal, 0) * transpose(transforms[i32(sphere.id)].modelMatrix)).xyz);

    hit_rec.front_face = dot(ray.dir, hit_rec.normal) < 0;
    if hit_rec.front_face == false {
        hit_rec.normal = -hit_rec.normal;
    }


    hit_rec.material = materials[i32(sphere.material_id)];
    return true;
}

fn hit_volume(sphere: Sphere, tmin: f32, tmax: f32, ray: Ray) -> bool {
    return false;
}

fn hit_quad(quad: Quad, tmin: f32, tmax: f32, ray: Ray) -> bool {
    return false;
}

// https://medium.com/@bromanz/another-view-on-the-classic-ray-aabb-intersection-algorithm-for-bvh-traversal-41125138b525
fn hit_aabb(box: AABB, tmin: f32, tmax: f32, ray: Ray, inv_dir: vec3f) -> bool {
    var t0s = (box.min - ray.origin) * inv_dir;
    var t1s = (box.max - ray.origin) * inv_dir;

    var tsmaller = min(t0s, t1s);
    var tbigger = max(t0s, t1s);

    var t_min = max(tmin, max(tsmaller.x, max(tsmaller.y, tsmaller.z)));
    var t_max = min(tmax, min(tbigger.x, min(tbigger.y, tbigger.z)));

    return t_max > t_min;
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