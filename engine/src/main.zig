const std = @import("std");
const core = @import("core/core.zig");
// TODO: Can probably move this into core.
const pdapi = @import("playdate_api_definitions.zig");
const panic_handler = @import("panic_handler.zig");
const PDSystemAllocator = @import("playdate_raw_allocator.zig").PDSystemAllocator;
const buffers = @import("graphics/buffers.zig");

pub const panic = panic_handler.panic;

pub export fn eventHandler(playdate: *pdapi.PlaydateAPI, event: pdapi.PDSystemEvent, arg: u32) callconv(.C) c_int {
    //TODO: replace with your own code!
    _ = arg;
    switch (event) {
        .EventInit => {
            //NOTE: Initalizing the panic handler should be the first thing that is done.
            //
            //      If a panic happens before calling this, the simulator or hardware will
            //      just crash with no message.
            panic_handler.init(playdate);

            // initialize the raw allocator that will be used for all the other backing allocations.
            var system_alloc = PDSystemAllocator.init(playdate);
            system_alloc.hasMoved();

            const zig_image = playdate.graphics.loadBitmap("assets/images/zig-playdate", null).?;
            var image_width: c_int = 0;
            var image_height: c_int = 0;
            playdate.graphics.getBitmapData(
                zig_image,
                &image_width,
                &image_height,
                null,
                null,
                null,
            );
            const font = playdate.graphics.loadFont("/System/Fonts/Roobert-20-Medium.pft", null).?;
            playdate.graphics.setFont(font);

            const global_state = system_alloc.allocator.create(core.Core) catch @panic("Ran out of memory creating Core");
            global_state.* = .{
                .playdate = playdate,
                .mem = system_alloc,
                .font = font,
                .zig_image = zig_image,
                .image_width = image_width,
                .image_height = image_height,
            };
            // this has to be done in two steps because allocator needs to know
            // raw_allocator's final resting place.
            global_state.mem.hasMoved();

            playdate.system.setUpdateCallback(update_and_render, global_state);
        },
        else => {},
    }
    return 0;
}

fn update_and_render(userdata: ?*anyopaque) callconv(.C) c_int {
    //TODO: replace with your own code!

    const core_instance: *core.Core = @ptrCast(@alignCast(userdata.?));
    const playdate = core_instance.playdate;
    const zig_image = core_instance.zig_image;

    const to_draw = "Hold Ⓐ";
    const text_width =
        playdate.graphics.getTextWidth(
            core_instance.font,
            to_draw,
            to_draw.len,
            .UTF8Encoding,
            0,
        );

    var draw_mode: pdapi.LCDBitmapDrawMode = .DrawModeCopy;
    var clear_color: pdapi.LCDSolidColor = .ColorWhite;

    var buttons: pdapi.PDButtons = 0;
    playdate.system.getButtonState(&buttons, null, null);
    //Yes, Zig fixed bitwise operator precedence so that this works!
    if (buttons & pdapi.BUTTON_A != 0) {
        draw_mode = .DrawModeInverted;
        clear_color = .ColorBlack;
    }

    playdate.graphics.setDrawMode(draw_mode);
    playdate.graphics.clear(@intCast(@intFromEnum(clear_color)));

    playdate.graphics.drawBitmap(zig_image, 0, 0, .BitmapUnflipped);
    const pixel_width = playdate.graphics.drawText(
        to_draw,
        to_draw.len,
        .UTF8Encoding,
        @divTrunc(pdapi.LCD_COLUMNS - text_width, 2),
        pdapi.LCD_ROWS - playdate.graphics.getFontHeight(core_instance.font) - 20,
    );
    _ = pixel_width;

    playdate.graphics.fillRect(0, 0, 50, 50, @intFromEnum(pdapi.LCDSolidColor.ColorBlack));
    const back_buffer = buffers.BackBuffer.init(playdate.graphics.getFrame());

    const render_buffer = core_instance.mem.allocator.create(buffers.RenderBuffer) catch @panic("ran out of memory");
    defer core_instance.mem.allocator.destroy(render_buffer);
    var color: buffers.RenderColor = 5;
    for (0..buffers.BackBuffer.height) |y| {
        color += 1;
        for (0..buffers.BackBuffer.width) |x| {
            render_buffer.setPixel(x, y, .{ .color = color, .depth = 0 });
        }
    }
    render_buffer.ditherAndBlit(&back_buffer);
    playdate.graphics.markUpdatedRows(0, buffers.BackBuffer.height);

    //returning 1 signals to the OS to draw the frame.
    //we always want this frame drawn
    return 1;
}
