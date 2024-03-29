const std = @import("std");
const mach = @import("mach");

const content_dir = "skyboxes/";

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const mach_dep = b.dependency("mach", .{
        .target = target,
        .optimize = optimize,
        // limit to core
        .core = true,
    });

    const zmath_pkg = @import("zmath").package(b, target, optimize, .{});
    const zstbi_pkg = @import("zstbi").package(b, target, optimize, .{});

    const app = try mach.CoreApp.init(b, mach_dep.builder, .{
        .name = "hooray",
        .src = "src/main.zig",
        .target = target,
        .optimize = optimize,
        .deps = &[_]std.Build.Module.Import{
            //     .{
            //     .name = "model3d",
            //     .module = b.dependency("mach_model3d", .{
            //         .target = target,
            //         .optimize = optimize,
            //     }).module("mach-model3d"),
            // }, .{
            // .{
            //     .name = "assets",
            //     .module = b.dependency("mach_core_example_assets", .{
            //         .target = target,
            //         .optimize = optimize,
            //     }).module("mach-core-example-assets"),
            // },
            .{ .name = "zmath", .module = zmath_pkg.zmath },
            .{ .name = "zstbi", .module = zstbi_pkg.zstbi },
        },
    });

    app.compile.root_module.addImport("zstbi", zstbi_pkg.zstbi);
    app.compile.root_module.addImport("zmath", zmath_pkg.zmath);

    zstbi_pkg.link(app.compile);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = thisDir() ++ "/" ++ content_dir },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/" ++ content_dir,
    });
    app.compile.step.dependOn(&install_content_step.step);

    if (b.args) |args| app.run.addArgs(args);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    // const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    // run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);
    run_step.dependOn(&app.run.step);

    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    // // const mach_pkg = @import("mach").package(b, target, optimize, .{});
    // // TODO: for some reason this is not working
    // zmath_pkg.link(exe_unit_tests);
    // // mach_dep.package(b, target, optimize, .{}).link(exe_unit_tests);

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // // Similar to creating the run step earlier, this exposes a `test` step to
    // // the `zig build --help` menu, providing a way for the user to request
    // // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.root_module.addImport("zmath", zmath_pkg.zmath);
    unit_tests.root_module.addImport("zstbi", zstbi_pkg.zstbi);
    unit_tests.root_module.addImport("mach", mach_dep.module("mach"));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
