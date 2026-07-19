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

var c_goo: Context = undefined;

fn foo() callconv(.c) void {
    std.debug.print("you called foo\n", .{});
    set_context(&c_goo); // jump into goo
}
fn goo() callconv(.c) void {
    std.debug.print("you called goo\n", .{});
}

fn stackTop(stack: []u8) ?*anyopaque {
    const top: usize = @intFromPtr(stack.ptr) + stack.len;
    const aligned: usize = top & ~@as(usize, 15);
    const sp: usize = aligned - 128;
    return @ptrFromInt(sp);
}
pub fn main() void {
    var stack_foo: [4096]u8 = undefined;
    var stack_goo: [4096]u8 = undefined;

    c_goo = .{
        .rip = @ptrCast(@constCast(&goo)),
        .rsp = stackTop(&stack_goo),
    };

    var c_foo: Context = .{
        .rip = @ptrCast(@constCast(&foo)),
        .rsp = stackTop(&stack_foo),
    };

    set_context(&c_foo); // jump into foo

}
