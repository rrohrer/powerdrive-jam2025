const pdapi = @import("../playdate_api_definitions.zig");
const pdmem = @import("../playdate_raw_allocator.zig");
const std = @import("std");

/// This is the center of the game engine. It holds all of the main systems and
/// data that needs to exist to run a frame.  It is also what is passed into the
/// playdate `setUpdateCallback` for userdata.
pub const Core = struct {
    playdate: *pdapi.PlaydateAPI,
    mem: pdmem.PDSystemAllocator,
    zig_image: *pdapi.LCDBitmap,
    font: *pdapi.LCDFont,
    image_width: c_int,
    image_height: c_int,
};
