const std = @import("std");
const pdapi = @import("playdate_api_definitions.zig");

/// this is a raw allocator for that calls out to the playdate system
/// allocator. It can be used with the other zig allocation systems as a
/// backing allocator.
pub const RawAllocator = struct {
    playdate: *pdapi.PlaydateAPI,
    const Self = @This();

    pub fn init(playdate: *pdapi.PlaydateAPI) Self {
        return .{ .playdate = playdate };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
        std.debug.assert(@intFromEnum(alignment) <= comptime std.math.log2_int(usize, 8));
        const self: *Self = @ptrCast(@alignCast(context));
        return @ptrCast(self.playdate.system.realloc(null, len));
    }

    // TODO: This is wasteful. Consider something else that can actually shrink memory when things downsize.
    fn resize(_: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, _: usize) bool {
        std.debug.assert(@intFromEnum(alignment) <= comptime std.math.log2_int(usize, 8));
        return new_len <= memory.len;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
        std.debug.assert(@intFromEnum(alignment) <= comptime std.math.log2_int(usize, 8));
        const self: *Self = @ptrCast(@alignCast(context));
        return @ptrCast(self.playdate.system.realloc(memory.ptr, new_len));
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, _: usize) void {
        std.debug.assert(@intFromEnum(alignment) <= comptime std.math.log2_int(usize, 8));
        const self: *Self = @ptrCast(@alignCast(context));
        _ = self.playdate.system.realloc(memory.ptr, 0);
    }
};

pub const PDSystemAllocator = struct {
    const Self = @This();

    raw_allocator: RawAllocator,
    allocator: std.mem.Allocator,

    pub fn init(playdate: *pdapi.PlaydateAPI) Self {
        const raw = RawAllocator.init(playdate);
        return Self{ .raw_allocator = raw, .allocator = undefined };
    }

    pub fn hasMoved(self: *Self) void {
        self.allocator = self.raw_allocator.allocator();
    }
};
