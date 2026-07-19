const std = @import("std");

pub const Context = extern struct {
    rip: ?*anyopaque = null,
    rsp: ?*anyopaque = null,
    rbx: ?*anyopaque = null,
    rbp: ?*anyopaque = null,
    r12: ?*anyopaque = null,
    r13: ?*anyopaque = null,
    r14: ?*anyopaque = null,
    r15: ?*anyopaque = null,
};

extern fn get_context(c: *Context) c_int;
extern fn set_context(c: *Context) void;
extern fn swap_context(out: *Context, in: *Context) void;

pub fn main() void {
    var x: i32 = 0;
    const xp: *volatile i32 = &x; // a volatile pointer to x to prevent compiler optimizations
    var c: Context = .{};

    const result: c_int = get_context(&c);
    _ = result;

    std.debug.print("a message\n", .{});

    if (xp.* == 0) {
        xp.* += 1;
        set_context(&c);
    }
}
