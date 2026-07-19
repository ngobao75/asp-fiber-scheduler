const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe1a = b.addExecutable(.{
        .name = "task1a",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/task1a.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe1a.root_module.addObjectFile(.{ .cwd_relative = "/opt/asp/libcontext.a" });
    exe1a.root_module.link_libc = true;
    b.installArtifact(exe1a);

    const exe1b = b.addExecutable(.{
        .name = "task1b",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/task1b.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe1b.root_module.addObjectFile(.{ .cwd_relative = "/opt/asp/libcontext.a" });
    exe1b.root_module.link_libc = true;
    b.installArtifact(exe1b);

    const run1a = b.addRunArtifact(exe1a);
    run1a.step.dependOn(b.getInstallStep());
    const run1a_step = b.step("run1a", "Run task 1a");
    run1a_step.dependOn(&run1a.step);

    const run1b = b.addRunArtifact(exe1b);
    run1b.step.dependOn(b.getInstallStep());
    const run1b_step = b.step("run1b", "Run task 1b");
    run1b_step.dependOn(&run1b.step);

    const exe2 = b.addExecutable(.{
        .name = "task2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe2.root_module.addObjectFile(.{ .cwd_relative = "/opt/asp/libcontext.a" });
    exe2.root_module.link_libc = true;
    b.installArtifact(exe2);

    const run2 = b.addRunArtifact(exe2);
    run2.step.dependOn(b.getInstallStep());
    const run2_step = b.step("run2", "Run task 2 demo");
    run2_step.dependOn(&run2.step);

    const exe3 = b.addExecutable(.{
        .name = "get_data_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/get_data_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe3.root_module.addObjectFile(.{ .cwd_relative = "/opt/asp/libcontext.a" });
    exe3.root_module.link_libc = true;
    b.installArtifact(exe3);

    const run3 = b.addRunArtifact(exe3);
    run3.step.dependOn(b.getInstallStep());
    const run3_step = b.step("run3", "Run get_data demo");
    run3_step.dependOn(&run3.step);

    // Add a test step that runs the scheduler_test.zig file
    const scheduler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/scheduler_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    scheduler_tests.root_module.addObjectFile(.{ .cwd_relative = "/opt/asp/libcontext.a" });
    scheduler_tests.root_module.link_libc = true;

    const run_tests = b.addRunArtifact(scheduler_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
