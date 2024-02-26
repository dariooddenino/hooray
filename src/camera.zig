const std = @import("std");
const core = @import("mach-core");
const zm = @import("zmath");
const utils = @import("utils.zig");
const main = @import("main.zig");

const PressedKeys = main.PressedKeys;
const toRadians = utils.toRadians;
const Vec = zm.Vec;
const Vec3 = [3]f32;
const Mat = zm.Mat;

// TODO there is some offset with the center, maybe that -1 I've seen in debug.
// TODO x rotation looks good now, y is wonky.
pub const Camera = struct {
    view_matrix: Mat,
    eye: Vec, // Location of the camera
    center: Vec, // Look at
    up: Vec,
    rotation_speed: f32 = 1,
    movement_speed: f32 = 0.1,

    moving: bool = false,

    pub fn init(eye: Vec) Camera {
        const center: Vec = .{ 0, 0, 0, 0 };
        const up: Vec = .{ 0, 1, 0, 0 };

        const view_matrix = zm.lookAtRh(eye, center, up);

        return Camera{
            .view_matrix = view_matrix,
            .eye = eye,
            .center = center,
            .up = up,
        };
    }

    pub fn setCamera(self: *Camera, eye: Vec, center: Vec, up: Vec) void {
        self.eye = eye;
        self.center = center;
        self.up = up;
        self.view_matrix = zm.lookAtRh(eye, center, up);
    }

    /// Arcball rotation
    pub fn rotate(self: *Camera, screen_width: u32, screen_height: u32, delta: [2]f32) void {
        self.moving = true;

        // step 1: Calculate amount of rotation given the mouse movement.
        // 360 degrees horizontally
        const x_angle = -delta[1] * (2 * std.math.pi / @as(f32, @floatFromInt(screen_width)));
        // 180 degrees vertically
        var y_angle = delta[0] * (std.math.pi / @as(f32, @floatFromInt(screen_height)));

        // Handle direction being the same as up
        // TODO lock going too much down too?
        // NOTE not sure it's the right angle.
        const direction = self.eye - self.center;
        const cos_angle: f32 = zm.dot3(direction, self.up)[0];
        if (cos_angle * (y_angle / @abs(y_angle)) > 0.99) {
            y_angle = 0;
        }

        // TODO I can't ignore the up/right vectors that were used. I have to find different functions
        // step 2: Rotate the camera around the center on the first axis
        const rotation_x = zm.rotationX(x_angle);
        const temp_eye = zm.mul(rotation_x, self.eye - self.center) + self.center;

        // step 3: Rotate the camera around the center on the second axis
        const rotation_y = zm.rotationY(y_angle);
        const eye = zm.mul(rotation_y, (temp_eye - self.center)) + self.center;

        const view_matrix = zm.lookAtRh(eye, self.center, self.up);

        self.eye = eye;
        self.view_matrix = view_matrix;
    }

    pub fn calculateMovement(self: *Camera, pressed_keys: PressedKeys) void {
        self.moving = true;
        _ = pressed_keys;
    }
};

// ========================================================================================

// pub const Camera = struct {
//     // perspective: Mat = zm.matFromArr(.{0} ** 16),
//     view_matrix: Mat = zm.matFromArr(.{0} ** 16),
//     rotation: Vec3 = .{ 0, 0, 0 },
//     position: Vec3 = .{ 0, 0, 0 },
//     // view_position: Vec = zm.splat(Vec, 0),
//     // fov: f32 = 0,
//     // znear: f32 = 0,
//     // zfar: f32 = 0,
//     rotation_speed: f32 = 1,
//     movement_speed: f32 = 0.1,
//     // updated: bool = false,

//     // TODO temp, see how this works without it
//     moving: bool = false,
//     // key_press: bool = false,

//     pub fn calculateMovement(self: *@This(), pressed_keys: PressedKeys) void {
//         std.debug.assert(pressed_keys.areKeysPressed());
//         self.moving = true;
//         const rotation_radians = Vec3{
//             toRadians(self.rotation[0]),
//             toRadians(self.rotation[1]),
//             toRadians(self.rotation[2]),
//         };
//         var camera_front = zm.Vec{ -zm.cos(rotation_radians[0]) * zm.sin(rotation_radians[1]), zm.sin(rotation_radians[0]), zm.cos(rotation_radians[0]) * zm.cos(rotation_radians[1]), 0 };
//         camera_front = zm.normalize3(camera_front);
//         if (pressed_keys.up) {
//             camera_front[0] *= self.movement_speed;
//             camera_front[1] *= self.movement_speed;
//             camera_front[2] *= self.movement_speed;
//             self.position = Vec3{
//                 self.position[0] + camera_front[0],
//                 self.position[1] + camera_front[1],
//                 self.position[2] + camera_front[2],
//             };
//         }
//         if (pressed_keys.down) {
//             camera_front[0] *= self.movement_speed;
//             camera_front[1] *= self.movement_speed;
//             camera_front[2] *= self.movement_speed;
//             self.position = Vec3{
//                 self.position[0] - camera_front[0],
//                 self.position[1] - camera_front[1],
//                 self.position[2] - camera_front[2],
//             };
//         }
//         if (pressed_keys.right) {
//             camera_front = zm.cross3(.{ 0.0, 1.0, 0.0, 0.0 }, camera_front);
//             camera_front = zm.normalize3(camera_front);
//             camera_front[0] *= self.movement_speed;
//             camera_front[1] *= self.movement_speed;
//             camera_front[2] *= self.movement_speed;
//             self.position = Vec3{
//                 self.position[0] - camera_front[0],
//                 self.position[1] - camera_front[1],
//                 self.position[2] - camera_front[2],
//             };
//         }
//         if (pressed_keys.left) {
//             camera_front = zm.cross3(.{ 0.0, 1.0, 0.0, 0.0 }, camera_front);
//             camera_front = zm.normalize3(camera_front);
//             camera_front[0] *= self.movement_speed;
//             camera_front[1] *= self.movement_speed;
//             camera_front[2] *= self.movement_speed;
//             self.position = Vec3{
//                 self.position[0] + camera_front[0],
//                 self.position[1] + camera_front[1],
//                 self.position[2] + camera_front[2],
//             };
//         }
//         self.updateViewMatrix();
//     }

//     fn updateViewMatrix(self: *@This()) void {
//         const rotation_x = zm.rotationX(toRadians(self.rotation[2]));
//         const rotation_y = zm.rotationY(toRadians(self.rotation[1]));
//         const rotation_z = zm.rotationZ(toRadians(self.rotation[0]));
//         const rotation_matrix = zm.mul(rotation_z, zm.mul(rotation_x, rotation_y));

//         const translation_matrix: zm.Mat = zm.translationV(.{
//             self.position[0],
//             self.position[1],
//             self.position[2],
//             0,
//         });
//         const view = zm.mul(translation_matrix, rotation_matrix);
//         self.view_matrix = view;
//         // self.view_matrix = zm.inverse(view);
//         // self.view_position = .{
//         //     -self.position[0],
//         //     self.position[1],
//         //     -self.position[2],
//         //     0.0,
//         // };
//         // self.updated = true;
//     }

//     pub fn setMovementSpeed(self: *@This(), speed: f32) void {
//         self.movement_speed = speed;
//     }

//     pub fn setRotationSpeed(self: *@This(), speed: f32) void {
//         self.rotation_speed = speed;
//     }

//     pub fn setRotation(self: *@This(), rotation: Vec3) void {
//         self.rotation = rotation;
//         self.updateViewMatrix();
//     }

//     pub fn rotate(self: *@This(), delta: [2]f32) void {
//         self.moving = true;
//         self.rotation[2] -= delta[1];
//         self.rotation[1] -= delta[0];
//         self.updateViewMatrix();
//     }

//     pub fn setPosition(self: *@This(), position: Vec3) void {
//         self.position = .{
//             position[0],
//             -position[1],
//             position[2],
//         };
//         self.updateViewMatrix();
//     }
// };

// ========================================================================================

// TODO refactor the setCamera mess please
// NOTE until I can see something, this is pointless.
// pub const Cameras = struct {
//     view_matrix: Mat = zm.matFromArr(.{0} ** 16),
//     eye: Vec = zm.splat(Vec, 0),
//     center: Vec = zm.splat(Vec, 0),
//     up: Vec = zm.splat(Vec, 0),
//     direction: Vec = zm.splat(Vec, 0),
//     rotate_angle: f32 = 0,
//     zoom_speed: f32 = 0.1,
//     move_speed: f32 = 0.01,
//     keypress_move_speed: f32 = 0.1,
//     moving: bool = false, // TODO not sure about these ones
//     key_press: bool = false,

//     pub fn setCamera(self: *Camera, eye: ?Vec, center: ?Vec, up: ?Vec) void {
//         if (eye) |e| {
//             self.eye = e;
//         }
//         if (center) |c| {
//             self.center = c;
//         }
//         if (up) |u| {
//             self.up = u;
//         }
//         // TODO normalize has other 2 versions, not sure...
//         self.direction = zm.normalize2(self.eye - self.center);
//         self.view_matrix = zm.lookAtLh(self.eye, self.center, self.up);
//     }

//     pub fn zoom(self: *Camera, delta: f32) void {
//         const eyex = self.direction[0] * self.zoom_speed * std.math.sign(delta);
//         const eyey = self.direction[1] * self.zoom_speed * std.math.sign(delta);
//         const eyez = self.direction[2] * self.zoom_speed * std.math.sign(delta);

//         self.eye = self.eye + Vec{ eyex, eyey, eyez };

//         self.setCamera(null, null, null);
//     }

//     // NOTE not sure about this
//     pub fn move(self: *Camera, old_coord: Vec, new_coord: Vec) Vec {
//         const d_x = (new_coord[0] - old_coord[0]) * std.math.pi / 180 * self.move_speed;
//         // const d_y = (new_coord[1] - old_coord[1]) * std.math.pi / 180 * self.move_speed;

//         self.rotate_angle = d_x;

//         const quat = zm.quatFromAxisAngle(self.direction, d_x);

//         self.eye = zm.rotate(quat, self.eye);

//         self.setCamera(null, null, null);
//     }

//     // pub fn rotate(self: *Camera) void {
//     //     const d_a = std.math.pi / 180.0 * self.move_speed;
//     //     const quat = zm.quatFromAxisAngle(self.direction, d_a);
//     //     self.eye = zm.rotate(quat, self.eye);
//     //     self.setCamera(null, null, null);
//     // }

//     pub fn rotate(self: *Camera, delta: [2]f32) void {
//         // I should update eye and center, and THEN update the view matrix...
//         self.view_matrix = zm.mul(self.view_matrix, zm.rotationX(delta[1] * self.move_speed));
//         self.view_matrix = zm.mul(self.view_matrix, zm.rotationY(delta[0] * self.move_speed));
//         self.moving = true;
//     }

//     pub fn stop(self: *Camera) void {
//         self.moving = false;
//     }

//     pub fn moveLeft(self: *Camera) void {
//         self.eye = self.eye + Vec{ self.keypress_move_speed, 0, 0, 0 };
//         self.center = self.center + Vec{ self.keypress_move_speed, 0, 0, 0 };
//         self.key_press = true;
//         self.setCamera(null, null, null);
//     }

//     pub fn moveRight(self: *Camera) void {
//         self.eye = self.eye - Vec{ self.keypress_move_speed, 0, 0, 0 };
//         self.center = self.center - Vec{ self.keypress_move_speed, 0, 0, 0 };
//         self.key_press = true;
//         self.setCamera(null, null, null);
//     }

//     pub fn moveUp(self: *Camera) void {
//         self.eye = self.eye - Vec{ 0, self.keypress_move_speed, 0, 0 };
//         self.center = self.center - Vec{ 0, self.keypress_move_speed, 0, 0 };
//         self.key_press = true;
//         self.setCamera(null, null, null);
//     }

//     pub fn moveDown(self: *Camera) void {
//         self.eye = self.eye + Vec{ 0, self.keypress_move_speed, 0, 0 };
//         self.center = self.center + Vec{ 0, self.keypress_move_speed, 0, 0 };
//         self.key_press = true;
//         self.setCamera(null, null, null);
//     }

//     pub fn moveForward(self: *Camera) void {
//         self.eye = self.eye + Vec{ 0, 0, self.keypress_move_speed, 0 };
//         self.center = self.center + Vec{ 0, 0, self.keypress_move_speed, 0 };
//         self.key_press = true;
//         self.setCamera(null, null, null);
//     }

//     pub fn moveBackward(self: *Camera) void {
//         self.eye = self.eye - Vec{ 0, 0, self.keypress_move_speed, 0 };
//         self.center = self.center - Vec{ 0, 0, self.keypress_move_speed, 0 };
//         self.key_press = true;
//         self.setCamera(null, null, null);
//     }

//     pub fn moveCamera(self: *Camera, event: core.KeyEvent) void {
//         switch (event.key) {
//             .w => self.moveForward(),
//             .a => self.moveLeft(),
//             .s => self.moveBackward(),
//             .d => self.moveRight(),
//             .q => self.moveUp(),
//             .e => self.moveDown(),
//             // .r => self.rotate(),
//             else => {},
//         }
//     }
// };

test "hello" {}
