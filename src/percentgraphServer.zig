const std = @import("std");
const StaticRing = @import("StaticRing.zig").StaticRing;
const Drawille = @import("drawille.zig");
pub const code_t = Drawille.code_t;

const rescaleOut = struct {
    data: f64,
    scale: u8,
};
//const rescaleOut = std.meta.Tuple(&.{ f64, u8 });
pub fn rescaleDataSize(data: usize, comptime scale: comptime_int) rescaleOut {
    const scales = " kMGTPEZY"; // metric unit scales starting from 0
    var output: f64 = @intToFloat(f64, data);
    var i: u8 = 0;
    while (output >= scale) {
        // TODO break out the 1024 case so it can use int bitshifting
        output /= scale;
        i += 1;
    }

    return .{
        .data = output,
        .scale = scales[i],
    };
    //return .{ output, scales[i] };
}
pub fn rescaleDataMetric(data: usize) rescaleOut {
    return rescaleDataSize(data, 1000);
}
pub fn rescaleDataBin(data: usize) rescaleOut {
    // TODO try a version that will do bitshifting and then somehow get the decimal part after or something
    return rescaleDataSize(data, 1 << 10);
}
fn truncateFloatDigits(data: f64, num_digits: u10) f64 {
    var thresh: usize = 1;
    var i = num_digits;
    while (i > 0) : (i -= 1) {
        thresh *= 10;
    }
    var mult_factor: f64 = 1;
    var shifted_data = data;
    var thresh_f = @intToFloat(f64, thresh);
    if (data != 0) {
        if (data < thresh_f) {
            thresh_f /= 10;
            while (shifted_data < thresh_f) {
                shifted_data *= 10;
                mult_factor /= 10;
            }
        } else {
            while (shifted_data >= thresh_f) {
                shifted_data /= 10;
                mult_factor *= 10;
            }
        }
    }
    return @round(shifted_data) * mult_factor;
}

pub fn getCacheDir(allocator: std.mem.Allocator, dir: []const u8) !std.ArrayList(u8) {
    var cache_dir = std.ArrayList(u8).init(allocator);
    // TODO maybe just move to a scheme using std.fs.getAppDataDir
    if (std.os.getenv("XDG_CACHE_HOME")) |XDG_CACHE_HOME| {
        const homecache_size = XDG_CACHE_HOME.len + 1 + dir.len;
        try cache_dir.ensureTotalCapacity(homecache_size);
        cache_dir.appendSliceAssumeCapacity(XDG_CACHE_HOME);
    } else {
        const HOME = std.os.getenv("HOME") orelse return error.NoHome;
        const cache = "/.cache";
        const homecache_size = HOME.len + 1 + cache.len + 1 + dir.len;
        try cache_dir.ensureTotalCapacity(homecache_size);
        cache_dir.appendSliceAssumeCapacity(HOME);
        cache_dir.appendSliceAssumeCapacity(cache);
    }
    cache_dir.appendAssumeCapacity('/');
    cache_dir.appendSliceAssumeCapacity(dir);
    const mode = std.os.S.IRUSR | std.os.S.IWUSR | std.os.S.IXUSR;
    // TODO handle mkdir -p
    std.os.mkdir(cache_dir.items, mode) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    return cache_dir;
}

pub fn PercentGraphServer(comptime T: type, comptime num_save: comptime_int, comptime num_graphs: comptime_int, comptime num_percents: comptime_int) type {
    return struct {
        clean_exit: bool = false,
        run: bool = true,
        on_client_request_func: ?client_request_func_t = null,
        socket_addr: std.os.sockaddr.un,
        connection_socket: std.os.socket_t,
        save: [num_save]stored_t,
        units: [num_percents]code_t,
        delimeters: [num_percents]code_t = [_]code_t{' '} ** num_percents,
        percents: StaticRing([num_graphs]percent_t, perc_stored),
        // TODO consider making its size confugurable, perce_stored isnt configurable and this height is hard coded
        canvas: Drawille.StaticCanvas(perc_stored, Drawille.y_per_block) = .{},
        //buffer: std.ArrayList(u8),
        //_raw_buffer: [buff_size]u8 = undefined,
        //_alloc: std.mem.Allocator,
        buffer: [buff_size]u8 = undefined,
        send_len: u32 = 0,

        const Self = @This();
        pub const percent_t = u32;
        pub const stored_t = T;
        // TODO consider passing self into the function
        pub const client_request_func_t = *const fn (*Self) void;
        pub const num_graph_perc = num_graphs;
        pub const num_print_perc = num_percents;
        pub const num_saved = num_save;
        const perc_stored = 8;
        // from the utf-8 man page: "* UTF-8  encoded  UCS  characters  may  be  up  to six bytes long, however the Unicode standard specifies no characters above"
        //const bytes_per_unicode = 6;
        const bytes_per_unicode = 4;
        //const buff_size = perc_stored / 2 + (1 + 4 + 1 + 1) * num_percents + 1;
        // + (1 delim + 4 digits of num (usually with .) + 1 unit size modifier (k,M,G,...) + 1 unit) per percent to print
        // + 1 null character for good measure
        const buff_size = (perc_stored * bytes_per_unicode) / Drawille.x_per_block + (1 * bytes_per_unicode + 4 + 1 + 1 * bytes_per_unicode) * num_percents + 1;

        pub fn init(filebase: []u8) !Self {
            return Self.initUnits(filebase, [_]code_t{'%'} ** num_percents);
        }
        pub fn initUnits(filebase: []u8, units: [num_percents]code_t) !Self {
            var self = Self{
                .socket_addr = .{
                    .family = std.os.AF.UNIX,
                    .path = undefined,
                },
                .connection_socket = undefined,
                .save = undefined,
                .units = undefined,
                //.buffer = undefined,
                .percents = .{
                    ._dataarray = [_][num_graphs]percent_t{[_]percent_t{0} ** num_graphs} ** perc_stored,
                },
                //._alloc = undefined,
            };
            if (units.len != num_percents) {
                return error.WrongSize;
            }
            //// TODO do i need to attache this to the struct as well?
            //var fba = std.heap.FixedBufferAllocator.init(&self._raw_buffer);
            //self._alloc = fba.allocator();
            //self.buffer = try @TypeOf(self.buffer).initCapacity(self._alloc, buff_size);
            std.mem.copy(code_t, &self.units, &units);

            // TODO secure the creation of this socket:
            //  - chmod it before touching the fs
            @memset(&self.socket_addr.path, '\x00', @sizeOf(@TypeOf(self.socket_addr.path)));
            std.mem.copy(u8, self.socket_addr.path[0..], filebase);
            std.mem.copy(u8, self.socket_addr.path[filebase.len..], ".sock");
            self.connection_socket = try std.os.socket(self.socket_addr.family, std.os.SOCK.STREAM, 0);
            std.os.fchmod(self.connection_socket, std.os.S.IRUSR | std.os.S.IWUSR) catch |err|
                std.debug.print("failed to fchmod socket: {}\n", .{err});
            return self;
        }
        pub fn setDelimeters(self: *Self, delims: []const code_t) void {
            std.debug.assert(delims.len == num_percents);
            std.mem.copy(code_t, &self.delimeters, delims);
        }
        pub fn saveDatas(self: *Self, to_save: []const stored_t) void {
            std.debug.assert(to_save.len == num_save);
            std.mem.copy(stored_t, &self.save, to_save);
        }
        pub fn getDatas(self: *const Self) *const [num_save]stored_t {
            return &self.save;
        }
        pub fn setPercents(self: *Self, cur_graphs: [num_graphs]percent_t, cur_percents: []const stored_t) void {
            // TODO maybe make the cur_percents not the same type as stored_t
            self.percents.setHead(cur_graphs);
            // TODO make this size configurable
            var percent_iter = self.percents.iterator();
            var i: u32 = 0;
            self.canvas.clear();
            while (percent_iter.next()) |percent_arr| {
                for (percent_arr) |perc| {
                    const limited_perc = if (perc >= 100) 99 else perc;
                    const x = @TypeOf(self.canvas).width * Drawille.x_per_block - 1 - i;
                    const y = Drawille.y_per_block - 1 - limited_perc / 25;
                    self.canvas.set(x, y) catch unreachable;
                }
                i += 1;
            }
            std.debug.assert(cur_percents.len == num_print_perc);
            //self.buffer.clearRetainingCapacity();
            //const buff_writer = self.buffer.writer();
            var bufstream = std.io.fixedBufferStream(&self.buffer);
            const buff_writer = bufstream.writer();
            //self.canvas.writeUnicode(buff_writer);
            //buff_writer.print("{}", .{self.canvas});
            self.canvas.draw(buff_writer) catch unreachable;
            for (self.units) |unit, ind| {
                switch (unit) {
                    @as(code_t, '%') => buff_writer.print("{u}{:4}%", .{ self.delimeters[ind], cur_percents[ind] }) catch unreachable,
                    else => {
                        //const scale = comptime switch (unit) {
                        //    @as(code_t, 'b'), @as(code_t, 'B') => 1 << 10,
                        //    else => 1000,
                        //};
                        //const scaled = rescaleDataSize(cur_percents[ind], scale);
                        const scaled = switch (unit) {
                            @as(code_t, 'b'), @as(code_t, 'B') => rescaleDataBin(cur_percents[ind]),
                            else => rescaleDataMetric(cur_percents[ind]),
                        };
                        //const trunc = truncateFloatDigits(scaled.data, 3);
                        var tmp_buf: [4]u8 = undefined;
                        var tmp_bufstream = std.io.fixedBufferStream(&tmp_buf);
                        const tmp_buff_writer = tmp_bufstream.writer();
                        //std.fmt.formatFloatDecimal(trunc, .{}, tmp_buff_writer) catch {};
                        std.fmt.formatFloatDecimal(scaled.data, .{}, tmp_buff_writer) catch {};
                        //buff_writer.print("{u}{d:4}{c}{u}", .{ self.delimeters[ind], trunc, scaled.scale, unit }) catch unreachable;
                        buff_writer.print("{u}{s}{c}{u}", .{ self.delimeters[ind], tmp_buf, scaled.scale, unit }) catch unreachable;
                        //std.debug.print("trunc {} = {d:4} ({s})\n", .{ scaled.data, trunc, tmp_buf });
                        ////buff_writer.print("{u}", .{ self.delimeters[ind] }) catch unreachable;
                        //std.fmt.formatUnicodeCodepoint(self.delimeters[ind], .{}, buff_writer) catch unreachable;
                        //const precision: usize = if (scaled.data < 10) 2 else if (scaled.data < 100) 1 else 0;
                        //std.fmt.formatFloatDecimal(scaled.data, .{ .precision = precision }, buff_writer) catch unreachable;
                        //buff_writer.print("{c}{u}", .{ scaled.scale, unit }) catch unreachable;
                    },
                }
            }
            self.send_len = @truncate(u32, buff_writer.context.pos);
        }
        pub fn onClientRequest(self: *Self, func: client_request_func_t) void {
            self.on_client_request_func = func;
        }
        pub fn runServerFunc(self: *Self, func: client_request_func_t) !void {
            self.onClientRequest(func);
            try self.runServer();
        }
        pub fn runServer(self: *Self) !void {
            // do cleanup on any errors
            errdefer self.cleanup() catch unreachable;
            const on_client_request_func = self.on_client_request_func orelse return error.NoClientFunc;
            // TODO probably have some sort of error printout like perror when this happens so the user has some understanding of whats happening
            try self.secureBindSocket();
            // TODO how big should the backlog be?
            try std.os.listen(self.connection_socket, 50);
            std.debug.print("ready for connections!\n", .{});
            const max_errors = 5;
            var num_errors: u8 = 0;
            while (self.run) {
                // NOTE doing non-blocking requests for 2 reasons:
                //  1.  really not necessary, worse when dealing with single connections at a time and i probably couldnt really overwhelm it enough in this use case to see it be better
                //  2.  this server kinda expects that the connections be spaced out because adequate time in between is really needed for this to function right for calculating percents (bad if connections came in at the same time and no work was done, cant divide by 0)
                //      - to that note, should have some div by 0 things handled
                //      - also should consider a minimum time before calculating new, otherwise it would just return the existing answer
                //      - also should consider using some buffer of data instead of always calculating from the last point to smooth things out a little, even if the update rate is high
                const data_socket = std.os.accept(self.connection_socket, null, null, 0) catch |err| {
                    num_errors += 1;
                    if (num_errors < max_errors) {
                        std.debug.print("got error #{} accepting connection ({}), will try again\n", .{ num_errors, err });
                        std.time.sleep(@as(u64, num_errors) * 1000000000);
                        continue;
                    } else {
                        std.debug.print("failed to connect {} times..\n", .{num_errors});
                        return err;
                    }
                };
                // close the socket anytime we exit this loop scope
                defer std.os.close(data_socket);
                // run server stuff
                on_client_request_func(self);
                //std.debug.print("len: {}\n", .{self.buffer.items.len});
                //const buffsize = @truncate(u32, self.buffer.items.len);
                const buffsize = self.send_len;
                _ = std.os.send(data_socket, std.mem.sliceAsBytes(@ptrCast(*const [1]@TypeOf(buffsize), &buffsize)), 0) catch |err| switch (err) {
                    // TODO figure out what other errors might be in this category of errors to just move on from instead of dying
                    error.SystemResources, error.BrokenPipe => {
                        std.debug.print("could not send to client: {}\n", .{err});
                        continue;
                    },
                    else => return err,
                };
                // TODO figure out how to do this error handling the same as the last case without copying it like i did here
                //  - maybe just save the output value and try sending again and see if either is an error?
                //_ = std.os.send(data_socket, self.buffer.items, 0) catch |err| switch (err) {
                _ = std.os.send(data_socket, self.buffer[0..self.send_len], 0) catch |err| switch (err) {
                    // TODO figure out what other errors might be in this category of errors to just move on from instead of dying
                    error.SystemResources, error.BrokenPipe => {
                        std.debug.print("could not send to client: {}\n", .{err});
                        continue;
                    },
                    else => return err,
                };
            }
        }
        fn secureBindSocket(self: *const Self) !void {
            // secure the creation of this socket:
            //  1.  make sure the dir is locked down
            //      - TODO remove file in its place if exists?
            //      - try to create dir with right permissions
            //      - if dir exists, then try to chmod it
            const basedir = std.fs.path.dirname(std.mem.sliceTo(&self.socket_addr.path, '\x00')).?;
            const S = std.os.S;
            const dirmode: u32 = S.IRUSR | S.IWUSR | S.IXUSR | S.ISVTX;
            std.os.mkdir(basedir, dirmode) catch |err| switch (err) {
                error.PathAlreadyExists => {
                    var dir = try std.fs.openIterableDirAbsolute(basedir, .{ .access_sub_paths = true });
                    defer dir.close();
                    try dir.chmod(dirmode);
                },
                else => return err,
            };
            //  2. remove file in socket's place if it exists
            std.os.unlinkZ(@ptrCast(*const [self.socket_addr.path.len:0]u8, &self.socket_addr.path)) catch |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            };
            //  3. bind socket
            try std.os.bind(self.connection_socket, @ptrCast(*const std.os.sockaddr, &self.socket_addr), @sizeOf(@TypeOf(self.socket_addr)));
            //  4. chmod socket path
            {
                std.debug.print("trying to chmod '{s}'\n", .{@ptrCast([*:0]const u8, &self.socket_addr.path)});
                const maybe_sockfile = std.fs.openFileAbsoluteZ(@ptrCast([*:0]const u8, &self.socket_addr.path), .{ .mode = std.fs.File.OpenMode.read_only }) catch |err| blk: {
                    std.debug.print("error opening socket to chmod: {}\n", .{err});
                    break :blk null;
                };
                if (maybe_sockfile) |sockfile| {
                    defer sockfile.close();
                    try sockfile.chmod(S.IRUSR | S.IWUSR);
                }
                //const O_PATH = 0o10000000;
                //const sockfd = try std.os.openZ(@ptrCast([*:0]const u8, &self.socket_addr.path), O_PATH, std.os.O.RDONLY);
                //defer std.os.close(sockfd);
                //try std.os.fchmod(sockfd, S.IRUSR | S.IWUSR);
            }
        }
        pub fn cleanup(self: *const Self) !void {
            std.debug.print("trying to clean up: removing socket {s}\n", .{@ptrCast([*:0]const u8, &self.socket_addr.path)});
            try std.os.unlinkZ(@ptrCast([*:0]const u8, &self.socket_addr.path));
        }
        pub fn stopRunning(self: *Self) void {
            self.run = false;
            // try shutting it down, not sure if this is helpful in any way, dont bother if it errors so we can get to trying to close the socket
            std.os.shutdown(self.connection_socket, std.os.ShutdownHow.both) catch |err|
                std.debug.print("error shutting down socket: {}\n", .{err});
            std.os.close(self.connection_socket);
        }
        pub fn handleSignal(self: Self) std.meta.FnPtr(fn (c_int) align(1) callconv(.C) void) {
            const ctx = struct {
                pub fn sigHandler(signal: c_int) align(1) callconv(.C) void {
                    self.stopRunning();
                    self.cleanup();
                    std.os.sigaction(@as(u6, signal), std.os.SIG.DFL, null);
                }
            };
            return ctx.sigHandler;
        }
    };
}

test "scale" {
    const out = rescaleDataBin(17790754);
    //std.debug.print("{d:.3}{c}\n", out);
    std.debug.print("{d:.3}{c}\n", .{ out.data, out.scale });
    //std.debug.print("tuple type: {}\n", .{@TypeOf(out)});
}

test "comptime for" {
    const cs = [_]u8{ 'a', 'b', 'c', 'd' };
    const us = [cs.len]u32{ 12345, 456789, 678910, 9361215 };
    inline for (cs) |c, i| {
        switch (c) {
            'c' => std.debug.print("c line, u: {}\n", .{us[i]}),
            else => {
                const scale = comptime if (c == 'b') 1 << 10 else 1000;
                const scaled = rescaleDataSize(us[i], scale);
                std.debug.print("{}{c} = {d:4.3}{c}{c}\n", .{ us[i], c, scaled.data, scaled.scale, c });
            },
        }
    }
}

const test_server_t = PercentGraphServer(u32, 1, 2, 2);
fn runTestServer(server: *test_server_t) void {
    std.debug.print("running\n", .{});
    const extent = 3 * 2 * std.math.pi / 2.0;
    const incr = std.math.pi / 8.0;
    const scale = 100000000;
    const prev_theta = server.getDatas();
    std.debug.print("prev theta: {}\n", .{prev_theta[0]});
    var theta = @intToFloat(f32, prev_theta[0]) / scale + incr;
    std.debug.print("theta: {d}\n", .{theta});
    var out_theta = [_]test_server_t.stored_t{@floatToInt(test_server_t.stored_t, theta * scale)};
    std.debug.print("out theta: {}\n", .{out_theta[0]});
    const data = [_]f32{
        @sin(theta),
        @cos(theta),
    };
    const percs = [_]test_server_t.stored_t{
        @floatToInt(u32, data[0] * 500 + 500),
        @floatToInt(u32, data[1] * 500 + 500),
    };
    const graph = [_]test_server_t.percent_t{
        @floatToInt(u32, (data[0] * 50) + 50),
        @floatToInt(u32, (data[1] * 50) + 50),
    };
    server.saveDatas(&out_theta);
    server.setPercents(graph, &percs);
    if (theta > extent) {
        server.stopRunning();
        return;
    }
}

test "simple server" {
    var buf: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();
    var cachedir_al = try getCacheDir(alloc, "test_server");
    try cachedir_al.appendSlice("/test");
    //var server = try test_server_t.initUnits(cachedir_al.items, [_]code_t{ 't', 'b' });
    //try server.runServerFunc(runTestServer);
}

test "trunc digits" {
    const num5 = 12345.6789;
    const num4 = num5 / 10.0;
    const num3 = num4 / 10.0;
    const num2 = num3 / 10.0;
    const num1 = num2 / 10.0;
    std.debug.print("\n", .{});
    std.debug.print("trunc: {} = {d:4}\n", .{ num5, truncateFloatDigits(num5, 3) });
    std.debug.print("trunc: {} = {d:4}\n", .{ num4, truncateFloatDigits(num4, 3) });
    std.debug.print("trunc: {} = {d:4}\n", .{ num3, truncateFloatDigits(num3, 3) });
    std.debug.print("trunc: {} = {d:4}\n", .{ num2, truncateFloatDigits(num2, 3) });
    std.debug.print("trunc: {} = {d:4}\n", .{ num1, truncateFloatDigits(num1, 3) });

    std.debug.print("trunc: {} = {d:4}\n", .{ 1.2, truncateFloatDigits(1.2, 3) });
    std.debug.print("trunc: {} = {d:4}\n", .{ 12.0, truncateFloatDigits(12.0, 3) });
}
