const std = @import("std");

pub fn main() !void {
    const argv = std.os.argv;
    if (argv.len < 2) {
        std.debug.print("you must give a socket path\n", .{});
        return error.Input;
    } else if (argv.len > 2) {
        std.debug.print("only using first argument for socket path", .{});
    }
    const socketname = std.mem.sliceTo(argv[1], 0);
    // TODO make sure this path exists before opening a socket
    var socket_addr = std.os.sockaddr.un{
        .family = std.os.AF.UNIX,
        .path = undefined,
    };
    std.mem.copy(u8, &socket_addr.path, socketname);
    const data_socket = try std.os.socket(socket_addr.family, std.os.SOCK.STREAM, 0);
    defer std.os.close(data_socket);
    try std.os.connect(data_socket, @ptrCast(*std.os.sockaddr, &socket_addr), @sizeOf(@TypeOf(socket_addr)));

    var linelen_in: c_int = undefined;
    _ = try std.os.recv(data_socket, @ptrCast([*]u8, &linelen_in)[0..@sizeOf(@TypeOf(linelen_in))], 0);
    std.debug.assert(linelen_in > 0);
    const linelen = @intCast(u32, linelen_in);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const wchar_t = u32;
    var line = try alloc.alloc(wchar_t, linelen + 1);
    defer alloc.free(line);
    //_ = try std.os.recv(data_socket, @ptrCast([]u8, line[0..linelen]), 0);
    //_ = try std.os.recv(data_socket, @ptrCast([*]u8, line)[0 .. linelen * @sizeOf(wchar_t)], 0);
    //_ = try std.os.recv(data_socket, std.mem.sliceAsBytes(line), 0);
    _ = try std.os.recv(data_socket, line, 0);
    line[linelen] = 0;

    const stdout = std.io.getStdOut().writer();

    //try stdout.print("{u}\n", .{uline});
    //var utf8 = (try std.unicode.Utf8View.init(line)).iterator();
    //while (utf8.nextCodepointSlice()) |codepoint| {
    //    std.debug.print("codepoint type: {}\n", .{@TypeOf(codepoint)});
    //    try stdout.print("{u}", .{codepoint});
    //}
    //try stdout.print("\n", .{});
    for (line) |codepoint| {
        // TODO surely theres a better way of dealing with this
        try std.fmt.formatUnicodeCodepoint(codepoint, .{}, stdout);
    }
    try stdout.print("\n", .{});
}

fn sizeof(val: anytype) usize {
    const val_type = @TypeOf(val);
    return @sizeOf(if (val_type == type) val else val_type);
}

test "sizeof" {
    var i: u32 = undefined;
    std.debug.print("i ({}) size: {}\n", .{ @TypeOf(i), sizeof(i) });
    std.debug.print("u32 size: {}\n", .{sizeof(u32)});
}
