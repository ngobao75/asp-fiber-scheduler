const std = @import("std");
const fiber_mod = @import("fiber.zig");
const scheduler_mod = @import("scheduler.zig");

const fiber = fiber_mod.fiber;

var test_order: [8]u8 = undefined;
var test_order_len: usize = 0;

fn recordA() callconv(.c) void {
    test_order[test_order_len] = 'A';
    test_order_len += 1;
    scheduler_mod.fiber_exit();
}

fn recordB() callconv(.c) void {
    test_order[test_order_len] = 'B';
    test_order_len += 1;
    scheduler_mod.fiber_exit();
}

fn yieldingRecordA() callconv(.c) void {
    test_order[test_order_len] = 'a';
    test_order_len += 1;
    scheduler_mod.yield();
    test_order[test_order_len] = 'A';
    test_order_len += 1;
    scheduler_mod.fiber_exit();
}

test "fiber.init sets a non-null entry point" {
    var f: fiber = undefined;
    f.init(recordA, null);
    try std.testing.expect(f.context.rip != null);
    try std.testing.expect(f.context.rsp != null);
}

test "scheduler runs spawned fibers in FIFO (round robin) order" {
    test_order_len = 0;
    var fa: fiber = undefined;
    var fb: fiber = undefined;
    fa.init(recordA, null);
    fb.init(recordB, null);

    scheduler_mod.spawn(&fa);
    scheduler_mod.spawn(&fb);
    scheduler_mod.do_it();

    try std.testing.expectEqualSlices(u8, "AB", test_order[0..test_order_len]);
}

test "yield lets another fiber run before resuming" {
    test_order_len = 0;
    var fa: fiber = undefined;
    var fb: fiber = undefined;
    fa.init(yieldingRecordA, null);
    fb.init(recordB, null);

    scheduler_mod.spawn(&fa);
    scheduler_mod.spawn(&fb);
    scheduler_mod.do_it();

    try std.testing.expectEqualSlices(u8, "aBA", test_order[0..test_order_len]);
}
