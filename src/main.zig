const std = @import("std");
const fiber_mod = @import("fiber.zig");
const scheduler_mod = @import("scheduler.zig");

const fiber = fiber_mod.fiber;

fn f1() callconv(.c) void {
    std.debug.print("fiber 1 before\n", .{});
    scheduler_mod.yield();
    std.debug.print("fiber 1 after\n", .{});
    scheduler_mod.fiber_exit();
}

fn f2() callconv(.c) void {
    std.debug.print("fiber 2\n", .{});
    scheduler_mod.fiber_exit();
}

pub fn main() void {
    var fa: fiber = undefined;
    var fb: fiber = undefined;

    fa.init(f1, null);
    fb.init(f2, null);

    scheduler_mod.spawn(&fa);
    scheduler_mod.spawn(&fb);

    scheduler_mod.do_it();
}
