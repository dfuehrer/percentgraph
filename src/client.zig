const std = @import("std");

pub fn main() !void {
    const argv = std.os.argv;
    if (argv.len < 2) {
        std.debug.print("you must give a socket path\n", .{});
        return error.Input;
    } else if (argv.len > 2) {
        std.debug.print("only using first argument for socket path", .{});
    }
    const socketname = std.mem.sliceTo(argv[1], '\x00');
    // TODO make sure this path exists before opening a socket
    var socket_addr = std.os.sockaddr.un{
        .path = [_]u8{'\x00'} ** @typeInfo(std.meta.fieldInfo(std.os.sockaddr.un, .path).field_type).Array.len,
    };
    std.mem.copy(u8, &socket_addr.path, socketname);
    const data_socket = try std.os.socket(socket_addr.family, std.os.SOCK.STREAM, 0);
    defer std.os.close(data_socket);
    try std.os.connect(data_socket, @ptrCast(*std.os.sockaddr, &socket_addr), @sizeOf(@TypeOf(socket_addr)));

    var linelen_in: u32 = undefined;
    //_ = try std.os.recv(data_socket, @ptrCast([*]u8, &linelen_in)[0..@sizeOf(@TypeOf(linelen_in))], 0);
    _ = try std.os.recv(data_socket, std.mem.sliceAsBytes(@ptrCast(*[1]@TypeOf(linelen_in), &linelen_in)), 0);
    std.debug.assert(linelen_in > 0);
    const linelen = @intCast(u32, linelen_in);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var line = try alloc.alloc(u8, linelen);
    defer alloc.free(line);
    _ = try std.os.recv(data_socket, line, 0);

    const stdout = std.io.getStdOut().writer();

    //std.debug.print("line: '{any}' ({})\n", .{ line, linelen });
    try stdout.print("{s}\n", .{line});
}
