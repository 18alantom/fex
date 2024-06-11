const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;

const release_queries: []const std.Target.Query = &.{
    .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    },
    // Does NOT compile
    // `no field named 'lstat' in enum 'os.linux.syscalls.Arm64'`
    // .{
    //     .cpu_arch = .aarch64,
    //     .os_tag = .linux,
    //     .abi = .gnu,
    // },
    // DOES NOT compile on aarch64-macos
    // Compiles on x86_64-linux
    .{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    },
    .{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    },
};
const is_running_on_macos = builtin.target.os.tag == .macos;

pub fn build(b: *Build) !void {
    // zig build | zig build install
    const exe = try addInstallCommand(b);

    // zig build run
    try addRunCommand(b, exe);

    // zig build release
    try addReleaseCommand(b);

    // zig build test
    try addTestCommand(b);
}

fn addInstallCommand(b: *Build) !*Build.Step.Compile {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "fex",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
    exe.linkLibC();
    return exe;
}

fn addRunCommand(b: *Build, exe: *Build.Step.Compile) !void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

/// Will build ReleaseSafe binaries for target queries
/// in `release_queries`.
///
/// Path to build artefacts will be:
///   zig-out/{arch}-{os}/fex
fn addReleaseCommand(b: *Build) !void {
    const release_step = b.step("release", "Build release binaries");
    for (release_queries) |query| {
        // macOS cannot build macOS targets.
        // Native build (i.e. with empty query) has to be run .
        if (is_running_on_macos and query.os_tag == .macos) continue;

        const target = b.resolveTargetQuery(query);
        const release_exe = b.addExecutable(.{
            .name = "fex",
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
            .single_threaded = true,
        });

        const custom_dest_dir = try query.zigTriple(b.allocator);
        const install_step = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{
                .override = .{ .custom = custom_dest_dir },
            },
        });
        release_exe.linkLibC();
        release_step.dependOn(&install_step.step);
    }
}

fn addTestCommand(b: *Build) !void {
    _ = b;
    // TODO: Add tests, make them work
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("main.zig"),
    // });
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
