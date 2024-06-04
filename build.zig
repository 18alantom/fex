const std = @import("std");

const release_queries: []const std.Target.Query = &.{
    .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    },
    .{
        // FIXME: macos doesn't compile with these
        // .cpu_arch = .aarch64,
        // .os_tag = .macos,
        // .abi = .none,
    },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig build install
    const exe = b.addExecutable(.{
        .name = "fex",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);
    exe.linkLibC();

    // zig build run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TODO: Add release step
    // zig build test
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("fs/Manager.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);

    // zig build release
    const release_step = b.step("release", "Build release binaries");
    for (release_queries) |query| {
        const release_exe = b.addExecutable(.{
            .name = "fex",
            .root_source_file = b.path("main.zig"),
            .target = b.resolveTargetQuery(query),
            .optimize = .ReleaseSafe,
            .single_threaded = true,
        });

        release_exe.linkLibC();

        const custom_dest_dir = try query.zigTriple(b.allocator);
        const install_step = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{
                .override = .{ .custom = custom_dest_dir },
            },
        });
        release_step.dependOn(&install_step.step);
    }
}
