# Fiber Scheduler (Zig)

A cooperative fiber/task scheduler implemented in Zig for Advanced System Programming,
using the provided `libcontext.a` System V ABI context-switching library.

## Author
Gia Bao Ngo (submitted individually )

## Environment
- Built and tested on csctcloud.uwe.ac.uk
- Zig version: 0.17.0-dev.1282+c0f9b51d8
- Depends on `/opt/asp/libcontext.a` and `/opt/asp/context.h`

## Repo layout
- `src/task1a.zig` — Task 1, part 1: get_context/set_context volatile loop
- `src/task1b.zig` — Task 1, part 2: foo/goo as fibers with manual stacks
- `src/fiber.zig` — Task 2: fiber struct
- `src/scheduler.zig` — Task 2: scheduler class, spawn/do_it/fiber_exit
- `src/main.zig` — Task 2/3: worked examples using the scheduler
- `build.zig` — build definitions for all executables and tests

## How to build and run
```bash
zig build run1a      # Task 1a demo
zig build run1b      # Task 1b demo
zig build run        # Task 2/3 scheduler demo
zig build test        # run unit tests
zig build test --summary all    # to get a confirmation with a summary when run unit tests
```

## Task 1 :Context operations 

### 1a : get_context/set_context loop

This program demonstrates the core mechanism behind fiber context switching
using a single stack (no manual stack setup yet, it will come in 1b).

The logic follows the assignment's pseudo-code directly:

```zig
var x: i32 = 0;
const xp: *volatile i32 = &x;
var c: Context = .{};

_ = get_context(&c);
std.debug.print("a message\n", .{});

if (xp.* == 0) {
    xp.* += 1;
    set_context(&c);
}
```

Running this prints `a message` **twice**.

**Why `get_context`/`set_context` produce two prints:**
`get_context(&c)` saves the current CPU state (instruction pointer, stack
pointer, and callee-saved registers) into `c`. The first time through,
`x == 0`, so the `if` body runs: `x` is incremented, then `set_context(&c)`
is called. `set_context` does not return normally — it restores the saved
state in `c`, which means execution resumes *as if `get_context` were
returning again*, right after its call site. This time, however, `x == 1`
because that increment persisted, so the `if` condition is false and the
program falls through to the end.

This is the same mechanism C's `setjmp`/`longjmp` uses, and it's why
`get_context` returns an `int` — a return value of `0` distinguishes "this
is the first, real call" from a later resumption via `set_context` (not
used to branch in this exercise, but relevant in later tasks).

**Why `volatile` is required:**
Without it, the compiler is allowed to assume that `x` doesn't change
between the `if` check and the end of the function, since from its
point of view, nothing in the visible control flow re-executes that
code. It has no way to know that `set_context` performs a jump back to
an earlier point in the program with the previous stack/register state
restored; that's implemented in hand-written assembly outside what Zig's
optimizer can see. As a result, without `volatile`, the compiler could
constant-fold `x == 0` to always be true (or eliminate the branch
entirely), producing incorrect behaviour. Marking the pointer to `x` as
`volatile` forces every read and write through it to actually happen, in
program order, with no caching or elimination. So the second, mutated
value of `x` is guaranteed to be seen when the branch re-executes.

## 1b :foo as a fiber (manual stack)

`foo` is launched by manually constructing a `Context`:
- `rsp` points into a locally-allocated 4096-byte buffer, adjusted to the
  top of that buffer (stacks grow downward), masked to 16-byte alignment
  per the SysV ABI, then offset by 128 bytes for the Red Zone.
- `rip` is set to the address of `foo` itself.

Calling `set_context(&c)` jumps directly into `foo`, which runs and prints
successfully.

### Observed crash on return

After `foo`'s body finishes, the program crashes with a General Protection
Fault, jumping to address `0xaaaaaaaaaaaaaaa9` (Zig's debug-mode "undefined
memory" poison pattern).

This is expected, not a bug. A normal function return works by popping a
return address off the stack that the *caller* pushed before the call.
Because `foo`'s stack was manually allocated and never had a real call
made onto it, there is no return address there — just uninitialized
memory. When `foo` executes its implicit `return`, the CPU pops that
poisoned value and tries to jump to it as if it were code, causing the
fault.

This demonstrates why the assignment brief requires fibers to call
`fiber_exit()` explicitly rather than returning normally: a manually
constructed stack has no valid return address for the CPU to fall back
into.

### goo - second fiber

`foo`, instead of returning (which crashes, as shown above), explicitly
calls `set_context(&c_goo)` at the end of its body to hand control to a
second fiber, `goo`, running on its own separately allocated stack.

Control cannot be handed off from `main` after the first `set_context`
call, since `set_context` never returns to its caller since any code after
`set_context(&c_foo)` in `main` is unreachable. The handoff has to happen
from *inside* the currently running fiber instead.

`goo` runs and prints successfully, then crashes on its own implicit
return for the same reason `foo` did, so its manually-built stack has no
valid return address either. This reinforces the need for an explicit
`fiber_exit()` mechanism, which Task 2/3 introduce.

## Task 2: Fiber class and scheduler
### `fiber` struct
The `fiber` struct bundles a `Context` and its own fixed-size stack
(64KB — see note under Task 3). Rather than a factory function that
builds and returns a `fiber` by value, initialization is done in place
via `init(self: *fiber, ...)`, called on an already-declared fiber
(`var f: fiber = undefined; f.init(...)`). This is necessary because the
stack's start address must be stable before computing `rsp` — if `init`
built a fiber locally and returned it by value, the struct (including
its 64KB stack) would be copied to a new address afterward, silently
invalidating any pointer computed against the original location.

### `scheduler`
The scheduler holds a FIFO queue of `*fiber` (via `std.ArrayList`,
popped from the front to preserve spawn order) and its own saved
`Context`, used as a re-entry point for the round-robin loop.

`do_it()` calls `get_context` on its own context once (the same
"save a resumable point" trick as Task 1a), then, while the queue is
non-empty, pops the next fiber and `set_context`s into it. Each fiber
returns control to the scheduler by calling `fiber_exit()`, which
`set_context`s back to the scheduler's saved point — this is what
replaces a normal function return, which fibers cannot use safely (see
Task 1b).

A single global scheduler instance, `s`, is required because
`fiber_exit()`, `yield()`, and `get_data()` all take **no arguments**
(per the fixed API), so a running fiber has no other way to reach "the
scheduler" except through shared global state.

**Bug found and fixed:** an early version of `do_it` took the scheduler
as a `self: *scheduler` parameter. This caused a segfault, because `self`
could be held in a caller-saved register, which is not preserved across
the manual context switch performed by `get_context`/`set_context` (only
callee-saved registers : rbx, rbp, r12-r15 survive). The fix was to
have `do_it` operate on the global `s` directly rather than through a
parameter, so state is always read from a fixed memory address.

### get_data

Each `fiber` carries an optional `?*anyopaque` data field, set at
creation via `init(function, data)`. The running fiber retrieves it
through the global `get_data()` function (no arguments, consistent with
`fiber_exit()`/`yield()`), which reads `s.current_.?.data`.

Since `?*anyopaque` is untyped, retrieving it requires two casts:
`@ptrCast` to the concrete pointer type, and `@alignCast` alongside it,
since Zig cannot statically verify that an untyped pointer's alignment
satisfies the target type's requirements.

## Task 3: Yield
`yield()` uses `swap_context(out, in)` rather than `set_context`, since it
needs to both save the currently-running fiber's execution point (so it
can resume later, exactly where it left off) and jump to the scheduler
in a single operation. Before yielding, the fiber re-enqueues itself at
the back of the run queue via `spawn`, since it hasn't finished — it's
only pausing.

The scheduler tracks the currently running fiber via a `current_` field,
set in `do_it()` right before jumping into a fiber, so `yield()` (which
takes no arguments per the required API) can find its own context to
save into.

### Bug: stack size

The initial 4096-byte stack size caused a segfault specifically on the
first resume of a yielded fiber (not on initial entry). The call chain
through `yield()` — including `spawn()`'s ArrayList append and allocator
calls, plus `std.debug.print`'s formatting — is deeper than the simple
fibers in Task 1b/2, and 4096 bytes proved insufficient headroom,
especially under Debug-build safety checks. Increasing STACK_SIZE to
64KB resolved it. This highlights that fiber stack sizing must account
for the full call depth used inside a fiber, including library and
allocator calls, not just the fiber's own body.

## Testing
Unit tests live in `src/scheduler_tests.zig` and run via `zig build test`.
Rather than asserting on printed output, test fibers record execution
order into a shared buffer, which is then checked for the expected
sequence.

Covered:
- `fiber.init` produces a non-null `rip`/`rsp`
- Fibers run in FIFO/round-robin order matching spawn order
- `yield()` correctly pauses a fiber, lets the next queued fiber run,
  and resumes the yielding fiber afterward at the right point

## References
- Benedict R. Gaster, Advanced Systems Programming module materials.
- context.h library derived from https://graphitemaster.github.io/fibers/
- Zig language documentation: https://ziglang.org/documentation/master/
