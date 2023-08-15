pub fn StaticRing(comptime T: type, comptime N: comptime_int) type {
    return struct {
        _dataarray: [N]T = undefined,
        _head_ind: usize = 0,

        const Self = @This();
        pub const size = N;
        pub const data_type = T;

        pub fn setTail(self: *Self, data: T) void {
            self._dataarray[self._head_ind] = data;
            self._head_ind += 1;
            if (self._head_ind == N) {
                self._head_ind = 0;
            }
        }
        pub fn setHead(self: *Self, data: T) void {
            if (self._head_ind == 0) {
                self._head_ind = N - 1;
            } else {
                self._head_ind -= 1;
            }
            self._dataarray[self._head_ind] = data;
        }
        pub fn iterator(self: *Self) Iterator {
            return .{
                .ind = self._head_ind,
                ._dataarray_ptr = &self._dataarray,
                ._head_ind = self._head_ind,
            };
        }
        pub const Iterator = struct {
            //ptr: [*]T,
            ptr: ?*T = null,
            ind: usize,
            _dataarray_ptr: *[N]T,
            _head_ind: usize,

            pub fn next(it: *Iterator) ?*T {
                if (it.ptr == null) {
                    it.ind = it._head_ind;
                } else {
                    if ((it.ind + 1) % N == it._head_ind) {
                        return null;
                    }
                    it.ind += 1;
                    if (it.ind == N) {
                        it.ind = 0;
                    }
                }
                // TODO maybe actually just increment the pointer for efficiency
                it.ptr = &it._dataarray_ptr[it.ind];
                return it.ptr;
            }
            pub fn reset(it: *Iterator) void {
                it.ind = it._head_ind;
                it.ptr = null;
            }
        };
    };
}

test "static ring" {
    const std = @import("std");
    const Drawille = @import("drawille.zig");

    const extent = 3 * 2 * std.math.pi / 2.0;
    const incr = std.math.pi / 8.0;
    const numels = @floatToInt(comptime_int, @ceil(extent / incr));
    var ring = StaticRing(f32, numels){};
    var theta: f32 = 0;
    while (theta < extent) {
        ring.setHead(@sin(theta));
        theta += incr;
    }
    //theta = 0;
    //while (theta < std.math.pi) {
    //    ring.setHead(@cos(theta));
    //    theta += incr;
    //}
    var iter = ring.iterator();
    //while (iter.next()) |s| {
    //    std.debug.print("{}\n", .{s.*});
    //}
    const height = 4 * Drawille.y_per_block;
    var canvas = Drawille.StaticCanvas(numels, height){};
    iter.reset();
    var i: usize = 0;
    while (iter.next()) |s| {
        //try canvas.set(i, @floatToInt(usize, s.* * @intToFloat(f32, height / 2) + @intToFloat(f32, height / 2)));
        try canvas.set(i, @floatToInt(usize, (s.* * (height - 1) / 2) + height / 2));
        i += 1;
    }
    try std.io.getStdOut().writer().print("sin:\n{}", .{canvas});
}
