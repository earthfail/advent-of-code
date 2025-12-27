const std = @import("std");
const assert = std.debug.assert;

const pedantic_memory: bool = false;
const Int = u64;
pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer if (pedantic_memory) {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("there was a leak. call a plumber");
        }
    };

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const input = try stdin.allocRemaining(allocator, .unlimited);
    defer if (pedantic_memory) allocator.free(input);

    var interval_it = std.mem.splitScalar(u8, input, ',');
    var intervals: [][2]Int = inpt: {
        var interval_count: usize = 0;
        while (interval_it.next()) |_| {
            interval_count += 1;
        }
        interval_it.reset();
        break :inpt try allocator.alloc([2]Int, interval_count);
    };
    defer if (pedantic_memory) allocator.free(intervals);

    var idx: usize = 0;
    while (interval_it.next()) |interval_slice| : (idx += 1) {
        const interval = std.mem.trim(u8, interval_slice, " \n\r\t");
        if (interval.len == 0) continue;

        var id_it = std.mem.tokenizeScalar(u8, interval, '-');
        var v: [2]Int = undefined;
        var i: u8 = 0;
        while (id_it.next()) |id_s| : (i += 1) {
            if (i >= 2) return error.IntervalParseError;
            v[i] = try std.fmt.parseInt(Int, id_s, 10);
        }
        // try stdout.print("{d},{d}\n", .{ v[0], v[1] });
        assert(idx < intervals.len);
        intervals[idx] = v;
    }

    const part = 2;
    if (part == 1) {
        part1(stdout, intervals);
    } else {
        part2(stdout, intervals);
    }
}
// ------------------------------------------------
//                   P A R T 2
// ------------------------------------------------
pub fn part2(stdout: *std.Io.Writer, intervals: [][2]Int) void {
    var sum: usize = 0;
    var ids_it: IdIterator = .{ .intervals = intervals };
    while (ids_it.next()) |id| {
        if (invalidId_part2(id)) {
            print(stdout, "{d}\n", .{id});
            sum += id;
        }
    }
    print(stdout, "sum is: {d}\n", .{sum});
    stdout.flush() catch {};
}
pub fn invalidId_part2(id: Int) bool {
    // 1 + q + q^2 +...+ q^{n-1} = (q^n-1)/(q-1)
    const digits_count: u32 = digitsCount(id);
    var q: Int = 10;
    var i: Int = 1; // number of digits that we can to repeat and check if give id
    for (0..digits_count / 2) |_| {
        const s = id % q;
        const duplicates = digits_count / i;
        const id_prime = s * (pow(q, duplicates) - 1) / (q - 1);
        if (id == id_prime)
            return true;

        q *= 10;
        i += 1;
    }
    return false;
}
// ------------------------------------------------
//                   P A R T 1
// ------------------------------------------------
pub fn part1(stdout: *std.Io.Writer, intervals: [][2]Int) void {
    var sum: usize = 0;
    var ids_it: IdIterator = .{ .intervals = intervals };
    while (ids_it.next()) |id| {
        if (false) {
            print(stdout, "{d},", .{id});
            if (ids_it.id_idx == 0) {
                print(stdout, "\n", .{});
            }
        }
        if (invalidId_part1(id)) {
            // print(stdout, "{d}\n", .{id});
            sum += id;
        }
    }
    print(stdout, "sum is: {d}\n", .{sum});
    stdout.flush() catch {};
}
pub fn invalidId_part1(id: Int) bool {
    const digits_count: u32 = digitsCount(id);
    const digits_count2 = digits_count / 2;
    if (digits_count2 * 2 != digits_count) {
        return false;
    }
    var pow10: usize = 1;
    for (0..digits_count2) |_| {
        pow10 *= 10;
    }
    const id_half = (id % pow10);
    const id_prime = id_half + id_half * pow10;

    return id_prime == id;
}
// ------------------------------------------------
//                    OPERATIONS
// ------------------------------------------------
pub fn pow(q: Int, n: Int) Int {
    var res: Int = 1;
    for (0..n) |_| {
        res *= q;
    }
    return res;
}

pub fn digitsCount(id: Int) u32 {
    var i: Int = id;
    var count: u32 = 0;
    if (false) while (i > 0) : (count += 1) {
        i /= 10;
    };
    while (true) {
        i /= 10;
        count += 1;
        if (!(i > 0))
            break;
    }
    return count;
}
// ------------------------------------------------
//                    ITERATORS
// ------------------------------------------------
const IdIterator = struct {
    intervals: [][2]Int,
    interval_idx: usize = 0,
    id_idx: usize = 0,

    fn peek(self: *IdIterator) ?Int {
        if (self.interval_idx < self.intervals.len) {
            return self.intervals[self.interval_idx][0] + @as(Int, @intCast(self.id_idx));
        }
        return null;
    }
    fn next(self: *IdIterator) ?Int {
        if (self.peek()) |res| {
            self.id_idx += 1;
            if (res + 1 > self.intervals[self.interval_idx][1]) {
                self.interval_idx += 1;
                self.id_idx = 0;
            }
            return res;
        }
        return null;
    }
};

fn print(writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch {};
}
