const STACK_SIZE = 64 * 1024; // 64 KiB

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

fn stackTop(stack: []u8) ?*anyopaque {
    const top: usize = @intFromPtr(stack.ptr) + stack.len;
    const aligned: usize = top & ~@as(usize, 15);
    const sp: usize = aligned - 128;
    return @ptrFromInt(sp);
}

pub const fiber = struct {
    context: Context,
    stack: [STACK_SIZE]u8,
    data: ?*anyopaque = null,

    pub fn init(self: *fiber, function: *const fn () callconv(.c) void, data: ?*anyopaque) void {
        self.context = .{
            .rip = @ptrCast(@constCast(function)),
            .rsp = stackTop(&self.stack),
        };
        self.data = data;
    }
};
