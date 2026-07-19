const std = @import("std");
const fiber_mod = @import("fiber.zig");
const Context = fiber_mod.Context;
const fiber = fiber_mod.fiber;

extern fn get_context(c: *Context) c_int;
extern fn set_context(c: *Context) void;
extern fn swap_context(old: *Context, new: *Context) void;

pub const scheduler = struct {
    fibers_: std.ArrayList(*fiber),
    context_: Context,
    current_: ?*fiber = null,

    pub fn init() scheduler {
        return .{
            .fibers_ = .empty,
            .context_ = undefined,
        };
    }

    pub fn spawn(self: *scheduler, alloc: std.mem.Allocator, f: *fiber) !void {
        try self.fibers_.append(alloc, f);
    }
};

pub var s: scheduler = scheduler.init();

var gpa = std.heap.DebugAllocator(.{}){};
const allocator = gpa.allocator();

pub fn spawn(f: *fiber) void {
    s.spawn(allocator, f) catch unreachable;
}

// Operates on the global `s` directly rather than taking `self` as a
// parameter, because a parameter would be held in a caller-saved
// register that is not preserved across the manual context switch
// performed by set_context/get_context — only callee-saved registers
// (rbx, rbp, r12-r15) survive the jump back into this function.
pub fn do_it() void {
    _ = get_context(&s.context_); // save re-entry point

    if (s.fibers_.items.len > 0) {
        const f = s.fibers_.orderedRemove(0);
        s.current_ = f;
        set_context(&f.context);
    }
    // queue empty -> falls through, do_it returns normally to main
}

pub fn yield() void {
    const f = s.current_.?;
    s.spawn(allocator, f) catch unreachable; // re-queue self at the back
    swap_context(&f.context, &s.context_); // pause here, resume scheduler
}

pub fn get_data() ?*anyopaque {
    return s.current_.?.data;
}

pub fn fiber_exit() void {
    set_context(&s.context_); // jump back to do_it's saved point

}
