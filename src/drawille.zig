const std = @import("std");

pub const x_per_block = 2;
pub const y_per_block = 4;
pub const code_t = u21;

pub const Canvas = struct {
    _width: usize,
    _height: usize,
    _canvas: []code_t,
    _allocator: std.mem.Allocator,

    const pixmap = [y_per_block][x_per_block]code_t{
        .{ 0x01, 0x08 },
        .{ 0x02, 0x10 },
        .{ 0x04, 0x20 },
        .{ 0x40, 0x80 },
    };
    const braille = 0x2800;
    const Self = @This();

    // TODO make a version of this that is returned from a wrapper function that takes the width and height and creates a static array in the struct
    //pub fn init(width: comptime_int, height: comptime_int) !Self {
    //    var canv = try canvas_type.initCapacity(allocator, width * height);
    //    return .{
    //        ._canvas = canv,
    //        ._width = width,
    //        ._height = height,
    //    };
    //}
    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Self {
        //var canv = try canvas_type.initCapacity(allocator, width * height);
        //canv.expandToCapacity();
        var canv = try allocator.alloc(code_t, (width / x_per_block) * (height / y_per_block));
        std.mem.set(code_t, canv, 0);
        return .{
            ._width = width / x_per_block,
            ._height = height / y_per_block,
            ._canvas = canv,
            ._allocator = allocator,
        };
    }
    pub fn deinit(self: *Self) void {
        //self._canvas.deinit();
        self._allocator.free(self._canvas);
    }
    pub fn clear(self: *Self) void {
        std.mem.set(code_t, self._canvas, 0);
    }

    pub fn set(self: *Self, x: usize, y: usize) !void {
        if (x >= (self._width * x_per_block) or x < 0) return error.OutOfBounds;
        if (y >= (self._height * y_per_block) or y < 0) return error.OutOfBounds;
        self._canvas[(y / y_per_block) * self._width + (x / x_per_block)] |= pixmap[y % y_per_block][x % x_per_block];
    }

    pub fn unset(self: *Self, x: usize, y: usize) !void {
        if (x >= (self._width * x_per_block) or x < 0) return error.OutOfBounds;
        if (y >= (self._height * y_per_block) or y < 0) return error.OutOfBounds;
        self._canvas[(y / y_per_block) * self._width + (x / x_per_block)] &= ~pixmap[y % y_per_block][x % x_per_block];
    }

    pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        for (self._canvas) |c, i| {
            switch (c) {
                0 => try writer.writeByte(' '),
                else => try writer.print("{u}", .{braille + c}),
            }
            if (i % self._width == self._width - 1 and i / self._width != self._height - 1) {
                try writer.writeByte('\n');
            }
        }
    }
    pub fn draw(self: *const Self, writer: anytype) !void {
        try self.format("{}", .{}, writer);
    }

    pub fn writeUnicode(self: *const Self, writer: anytype) !void {
        for (self._canvas) |c, i| {
            switch (c) {
                0 => try writer.writeIntNative(code_t, @as(code_t, ' ')),
                else => try writer.writeIntNative(code_t, braille + c),
            }
            if (i % self._width == self._width - 1 and i / self._width != self._height - 1) {
                try writer.writeIntNative(code_t, @as(code_t, '\n'));
            }
        }
    }
};

pub fn StaticCanvas(comptime canv_width: comptime_int, comptime canv_height: comptime_int) type {
    return struct {
        _canvas: [height][width]code_t = .{
            [_]code_t{0} ** width,
        } ** height,

        const pixmap = [y_per_block][x_per_block]code_t{
            .{ 0x01, 0x08 },
            .{ 0x02, 0x10 },
            .{ 0x04, 0x20 },
            .{ 0x40, 0x80 },
        };
        const braille = 0x2800;
        const Self = @This();
        pub const width = canv_width / x_per_block;
        pub const height = canv_height / y_per_block;

        pub fn clear(self: *Self) void {
            //std.mem.set(code_t, &self._canvas, 0);
            for (self._canvas) |*row| {
                for (row) |*c| {
                    c.* = 0;
                }
            }
        }

        pub fn set(self: *Self, x: usize, y: usize) !void {
            // TODO should these just be asserts? feels odd that this function would error
            if (x >= (width * x_per_block) or x < 0) return error.OutOfBounds;
            if (y >= (height * y_per_block) or y < 0) return error.OutOfBounds;
            self._canvas[y / y_per_block][x / x_per_block] |= pixmap[y % y_per_block][x % x_per_block];
        }

        pub fn unset(self: *Self, x: usize, y: usize) !void {
            if (x >= (width * x_per_block) or x < 0) return error.OutOfBounds;
            if (y >= (height * y_per_block) or y < 0) return error.OutOfBounds;
            self._canvas[y / y_per_block][x / x_per_block] &= ~pixmap[y % y_per_block][x % x_per_block];
        }

        pub fn format(self: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            for (self._canvas) |row, y| {
                for (row) |c| switch (c) {
                    0 => try writer.writeByte(' '),
                    else => try std.fmt.formatUnicodeCodepoint(braille + c, .{}, writer),
                };
                if (y != height - 1) {
                    try writer.writeByte('\n');
                }
            }
        }
        pub fn draw(self: *const Self, writer: anytype) !void {
            return self.format("{}", .{}, writer);
        }

        pub fn writeUnicode(self: *const Self, writer: anytype) !void {
            for (self._canvas) |row, y| {
                for (row) |c| switch (c) {
                    0 => try writer.writeIntNative(code_t, @as(code_t, ' ')),
                    else => try writer.writeIntNative(code_t, braille + c),
                };
                if (y != height - 1) {
                    try writer.writeIntNative(code_t, @as(code_t, '\n'));
                }
            }
        }
    };
}

test "drawille" {
    //const alloc = std.testing.allocator;
    //var d = try Canvas.init(alloc, 8, 4);
    //defer d.deinit();
    var d = StaticCanvas(8, 4){};
    try d.set(0, 0);
    try d.set(1, 1);
    try d.set(2, 2);
    try d.set(3, 3);
    try d.set(4, 1);
    try d.set(5, 0);
    try d.set(6, 2);
    try d.set(7, 0);
    //try d.draw(std.io.getStdOut().writer());
    try std.io.getStdOut().writer().print("test graph: {}\n", .{d});
}

test "format" {
    std.debug.print("{d:4}\n", .{4.356789});
    std.debug.print("{d:4}\n", .{43.56789});
    std.debug.print("{d:4}\n", .{435.6789});
}
