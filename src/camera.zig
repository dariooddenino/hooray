const std = @import("std");
const zm = @import("zmath");

const Vec = zm.Vec;
const Mat = zm.Mat;

pub const Camera = struct {
    view_matrix: Mat = Mat{},
    eye: Vec = Vec{},
    center: Vec = Vec{},
    up: Vec = Vec{},
    direction: Vec = Vec{},
    rotate_angle: f32 = 0,
    zoom_speed: f32 = 0.1,
    move_speed: f32 = 0.01,
    keypress_move_speed: f32 = 0.1,
    moving: bool = false, // TODO not sure about these ones
    key_press: bool = false,

    pub fn init(eye: Vec, center: Vec, up: Vec) Camera {
        var camera = Camera{};
        return camera.setCamera(eye, center, up);
    }

    fn setCamera(self: *Camera, eye: ?Vec, center: ?Vec, up: ?Vec) void {
        if (eye) |e| {
            self.eye = e;
        }
        if (center) |c| {
            self.center = c;
        }
        if (up) |u| {
            self.up = u;
        }
        // TODO normalize?
        self.direction = zm.normalize(center - eye);
        // TODO no idea here.
        self.view_matrix = zm.lookAtRh(eye, center, up);
    }

    pub fn zoom(self: *Camera, delta: f32) void {
        const eyex = self.direction[0] * self.zoom_speed * std.math.sign(delta);
        const eyey = self.direction[1] * self.zoom_speed * std.math.sign(delta);
        const eyez = self.direction[2] * self.zoom_speed * std.math.sign(delta);

        self.eye = self.eye + Vec{ eyex, eyey, eyez };

        self.setCamera(null, null, null);
    }

    pub fn move(self: *Camera, old_coord: Vec, new_coord: Vec) Vec {
        const d_x = (new_coord[0] - old_coord[0]) * std.math.pi / 180 * self.move_speed;
        // const d_y = (new_coord[1] - old_coord[1]) * std.math.pi / 180 * self.move_speed;

        self.rotate_angle = d_x;

        const quat = zm.quatFromAxisAngle(self.direction, d_x);

        self.eye = zm.rotate(quat, self.eye);

        self.setCamera(null, null, null);
    }

    pub fn moveLeft(self: *Camera) void {
        self.eye = self.eye + Vec{ self.keypress_move_speed, 0, 0 };
        self.center = self.center + Vec{ self.keypress_move_speed, 0, 0 };
        self.setCamera(null, null, null);
    }

    pub fn moveRight(self: *Camera) void {
        self.eye = self.eye - Vec{ self.keypress_move_speed, 0, 0 };
        self.center = self.center - Vec{ self.keypress_move_speed, 0, 0 };
        self.setCamera(null, null, null);
    }

    pub fn moveUp(self: *Camera) void {
        self.eye = self.eye - Vec{ 0, self.keypress_move_speed, 0 };
        self.center = self.center - Vec{ 0, self.keypress_move_speed, 0 };
        self.setCamera(null, null, null);
    }

    pub fn moveDown(self: *Camera) void {
        self.eye = self.eye + Vec{ 0, self.keypress_move_speed, 0 };
        self.center = self.center + Vec{ 0, self.keypress_move_speed, 0 };
        self.setCamera(null, null, null);
    }

    pub fn moveCamera(_: *Camera) void {
        // TODO Here various event listeners, I think I will have to do this backwards.
        // Or have this function accept events from webgpu.
    }
};

test "hello" {}
