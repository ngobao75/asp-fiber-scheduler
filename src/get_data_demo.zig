const std = @import("std");
const fiber_mod = @import("fiber.zig");
const scheduler_mod = @import("scheduler.zig");

const fiber = fiber_mod.fiber;

fn func1() callconv(.c) void {
    std.debug.print("fiber 1\n", .{});
    const dp: *i32 = @ptrCast(@alignCast(scheduler_mod.get_data().?));
    std.debug.print("fiber 1: {}\n", .{dp.*});
    dp.* += 1;
    scheduler_mod.fiber_exit();
}

fn func2() callconv(.c) void {
    const dp: *i32 = @ptrCast(@alignCast(scheduler_mod.get_data().?));
    std.debug.print("fiber 2: {}\n", .{dp.*});
    scheduler_mod.fiber_exit();
}

pub fn main() void {
    var d: i32 = 10;
    const dp: ?*anyopaque = @ptrCast(&d);

    var f1: fiber = undefined;
    var f2: fiber = undefined;

    f1.init(func1, dp);
    f2.init(func2, dp);

    scheduler_mod.spawn(&f1);
    scheduler_mod.spawn(&f2);

    scheduler_mod.do_it();
}
