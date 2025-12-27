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

    var arena_context = std.heap.ArenaAllocator.init(allocator);
    defer arena_context.deinit();
    const arena = arena_context.allocator();

    var lines: std.ArrayList([]u8) = .empty;
    defer if (pedantic_memory) lines.deinit(allocator);

    var line_it = tokenize(input, "\r\n");
    while (line_it.next()) |line| {
        const l = try lines.addOne(allocator);
        l.* = try arena.alloc(u8, line.len);
        for (line, l.*) |i, *o| {
            o.* = i - '0';
        }
    }

    const part: u8 = 2;
    if (part == 1) {
        part1(stdout, lines.items);
    } else {
        part2(stdout, lines.items);
    }
}
fn part2(stdout: *std.Io.Writer, lines: []const []const u8) void {
    print(stdout, "part2\n", .{});
    var sum: Int = 0;
    for (lines) |line| {
        var buffer: [12]u8 = undefined;
        const res = maxBatteryCharge(line, &buffer);
        print(stdout, "res={d}\n", .{res});
        sum += res;
    }
    print(stdout, "sum: {d}\n", .{sum});
    stdout.flush() catch {};
}

fn part1(stdout: *std.Io.Writer, lines: []const []const u8) void {
    var sum: usize = 0;
    for (lines) |line| {
        if (false) {
            var res: u8 = undefined;
            const maxv_idx: usize = maxValueIdx(line);
            if (maxv_idx < line.len - 1) {
                const second_max = maxv_idx + 1 + maxValueIdx(line[maxv_idx + 1 ..]);
                res = line[maxv_idx] * 10 + line[second_max];
            } else {
                const second_max = maxValueIdx(line[0..maxv_idx]);
                res = line[second_max] * 10 + line[maxv_idx];
            }
            sum += res;
            print(stdout, "res: {d}\n", .{res});
        } else if (false) {
            var max: u8 = 0;
            var max_digit: u8 = line[0];
            for (1..line.len) |i| {
                const v = max_digit * 10 + line[i];
                if (v > max) {
                    max = v;
                }
                if (line[i] > max_digit) {
                    max_digit = line[i];
                }
            }
            sum += max;
            print(stdout, "max: {d}\n", .{max});
        } else {
            // greedy
            var digits_buffer: [2]u8 = undefined;
            const ret = maxBatteryCharge(line, &digits_buffer);
            sum += ret;
            print(stdout, "ret: {d}\n", .{ret});
        }
    }
    print(stdout, "sum: {d}\n", .{sum});
    stdout.flush() catch {};
}
fn maxValueIdx(buffer: []const u8) usize {
    var max: u8 = 0;
    var idx: usize = 0;
    for (buffer, 0..) |v, i| {
        if (v > max) {
            max = v;
            idx = i;
        }
    }
    return idx;
}

fn maxBatteryCharge(line: []const u8, digits_buffer: []u8) Int {
    const min_len: usize = @min(line.len - 1, digits_buffer.len);
    for (0..min_len) |j| {
        digits_buffer[j] = line[line.len - 1 - j];
    }
    var i: usize = line.len - min_len;
    while (i > 0) {
        i -= 1;
        var v: u8 = line[i];
        var j: usize = digits_buffer.len;
        while (j > 0) {
            j -= 1;
            if (v >= digits_buffer[j]) {
                const tmp: u8 = digits_buffer[j];
                digits_buffer[j] = v;
                v = tmp;
            } else {
                break;
            }
        }
    }
    var num: Int = 0;
    var pow: Int = 1;
    for (digits_buffer) |d| {
        num += d * pow;
        pow *= 10;
    }
    return num;
}

pub fn tokenize(buffer: []const u8, delimiter: []const u8) std.mem.TokenIterator(u8, .any) {
    return std.mem.tokenizeAny(u8, buffer, delimiter);
}
pub fn print(writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch {};
}
