const pdapi = @import("../playdate_api_definitions.zig");
const std = @import("std");

/// This is a wrapper around the playdate screen buffer. It holds a pointer to the buffer and sets it.
pub const BackBuffer = struct {
    const Self = @This();
    pub const width: usize = pdapi.LCD_COLUMNS;
    pub const height: usize = pdapi.LCD_ROWS;
    const stride: usize = pdapi.LCD_ROWSIZE;

    data: [*c]u8,

    pub fn init(data: [*c]u8) Self {
        return Self{ .data = data };
    }

    pub fn setPixel(self: *const Self, x: usize, y: usize, color: pdapi.LCDSolidColor) void {
        const row_offset = y * stride;
        const col_byte = x / 8;
        const bit: u3 = @intCast((7) - x % 8);
        const pixel_byte = self.data[row_offset + col_byte];
        self.data[row_offset + col_byte] = switch (color) {
            .ColorBlack => pixel_byte & ~(@as(u8, 1) << bit),
            .ColorWhite => pixel_byte | (@as(u8, 1) << bit),
            else => pixel_byte,
        };
    }
};

pub const RenderColor = u8;

/// A type that represents the color and depth of a pixel in the `RenderBuffer`.
pub const ColorDepth8 = packed struct {
    color: RenderColor,
    depth: RenderColor,
};

/// A utility to wrap a buffer of `ColorDepth8` that can be used as a render target.
/// Essentially implements a primitive rendering API.
pub const RenderBuffer = struct {
    const Self = @This();
    const width: usize = pdapi.LCD_COLUMNS;
    const height: usize = pdapi.LCD_ROWS;

    data: [width * height]ColorDepth8,

    /// Set the color and depth of of the whole buffer to zero.
    pub fn clear(self: *Self) void {
        @memset(self.data[0..], 0);
    }

    /// Set a pixel at X Y to a Color value and *discard* exiting depth.
    pub fn setPixel(self: *Self, x: usize, y: usize, color: ColorDepth8) void {
        self.data[y * width + x] = color;
    }

    pub fn ditherAndBlit(self: *const Self, backbuffer: *const BackBuffer) void {
        const bayer_n = 4;
        const bayer_r = 255.0;
        const bayer_matrix_4x4: [bayer_n][bayer_n]f32 = .{
            .{ -0.5, 0, -0.375, 0.125 },
            .{ 0.25, -0.25, 0.375, -0.125 },
            .{ -0.3125, 0.1875, -0.4375, 0.0625 },
            .{ 0.4375, -0.0625, 0.3125, -0.1875 },
        };

        for (0..height) |y| {
            for (0..width) |x| {
                const bayer = bayer_matrix_4x4[y % bayer_n][x % bayer_n];
                const og_color: f32 = @floatFromInt(self.data[width * y + x].color);
                const scaled_color: u8 = @intFromFloat(std.math.clamp(og_color + (bayer_r * bayer), 0.0, 255.0));
                if (scaled_color > 128) {
                    backbuffer.setPixel(x, y, .ColorWhite);
                } else {
                    backbuffer.setPixel(x, y, .ColorBlack);
                }
            }
        }
    }
};
