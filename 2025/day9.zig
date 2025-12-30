const std = @import("std");
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.nine);
const math = std.math;

const print_debug: bool = false;

pub fn main() !void {
    try solveMain();
}

const Point = struct {
    data: [2]u32,

    const XY = enum(u8) { X = 0, Y = 1 };
    pub fn ref(self: *Point, axis: XY) *u32 {
        return &self.data[@intFromEnum(axis)];
    }
    pub fn x(self: Point) u32 {
        return self.data[0];
    }
    pub fn y(self: Point) u32 {
        return self.data[1];
    }
};
fn solveMain() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer if (false) {
        const status = gpa.deinit();
        if (status != .ok) {
            @panic("call luigi there is a leak!");
        }
    };

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    const input = try stdin.allocRemaining(allocator, .unlimited);

    const pairs = try parsePairs(allocator, input);
    if (print_debug) {
        for (pairs, 0..) |p, i| {
            std.debug.print("{d}: {any}\n", .{ i, p });
        }
    }
    const part = 2;
    if (part == 1) {
        solvePart1(pairs);
    } else {
        try solvePart2(allocator, pairs);
    }
}

fn solvePart1(pairs: []const Point) void {
    var max: u64 = 0;
    for (0..pairs.len - 1) |i| {
        for (i + 1..pairs.len) |j| {
            const area = calcArea(pairs[i], pairs[j]);
            max = @max(max, area);
        }
    }
    std.debug.print("max: {d}\n", .{max});
}

fn solvePart2(allocator: Allocator, pairs: []const Point) !void {
    if (false and !checkOrder(pairs)) {
        // My input is in counter clockwise order
        std.debug.print("assumption invalid: order is not in counter clockwise\n", .{});
        return;
    }

    const len2 = pairs.len / 2;
    const poly_lines_buff = try allocator.alloc(u32, pairs.len);
    // poly_lines[axis] stores contour lines parallel to axis.
    // to use the cache, we only store the index of the first point in the line
    // as stored in pairs list.
    const poly_lines: [2][]u32 = .{ poly_lines_buff[0..len2], poly_lines_buff[len2..] };
    assert(poly_lines[0].len == len2);
    assert(poly_lines[1].len == len2);

    var idx: [2]u32 = .{ 0, 0 };
    for (0..pairs.len) |i| {
        const j = (i + 1) % pairs.len;
        for (0..2, poly_lines, &idx) |axis, list, *k| {
            if (pairs[i].data[axis] == pairs[j].data[axis]) {
                list[k.*] = @intCast(i);
                k.* += 1;
            }
        }
    }
    assert(idx[0] == len2);
    assert(idx[1] == len2);

    for (0..2) |axis| {
        const ctx: Context = .{ .list = pairs, .axis = @enumFromInt(axis) };
        std.mem.sort(u32, poly_lines[axis], ctx, lessThanLine);
    }

    var max: u64 = 0;
    for (0..pairs.len - 1) |i| {
        for (i + 1..pairs.len) |j| {
            if (false) {
                for (0..pairs.len) |_| {
                    // sim an extra loop to check if it is fast enough
                    const area = calcArea(pairs[i], pairs[j]);
                    max = @max(max, area);
                }
            }
        }
    }
    std.debug.print("max: {d}\n", .{max});
    // std.mem.sort(Point, pairs, {}, lessThanFn);
    // assert(IsSortedByX(pairs));
}

const Context = struct {
    list: []const Point,
    axis: Point.XY,
};
fn lessThanLine(ctx: Context, lhs: u32, rhs: u32) bool {
    return ctx.list[lhs].data[@intFromEnum(ctx.axis)] < ctx.list[rhs].data[@intFromEnum(ctx.axis)];
}


fn checkOrder(pairs: []const Point) bool {
    // compute the clockwise integral of y which by divergence theorem equal to the area.
    // if the result is negative then the contour is counter clockwise
    var integral: i32 = 0;
    for (0..pairs.len) |i| {
        const j = (i + 1) % pairs.len;
        if (pairs[i].x() != pairs[j].x() and pairs[i].y() != pairs[j].y()) {
            return false;
        }

        const dx = @as(i32, @intCast(pairs[j].x())) - @as(i32, @intCast(pairs[i].x()));
        integral += dx * @as(i32, @intCast(pairs[i].y()));
    }
    assert(integral != 0);
    return integral < 0;
}
fn calcArea(p1: Point, p2: Point) u64 {
    const x: u64 = @abs(@as(i32, @intCast(p1.x())) - @as(i32, @intCast(p2.x()))) + 1;
    const y: u64 = @abs(@as(i32, @intCast(p1.y())) - @as(i32, @intCast(p2.y()))) + 1;
    const area = x * y;
    return area;
}

fn parsePairs(allocator: Allocator, input: []const u8) ![]Point {
    const pairs_count: usize = it_blk: {
        var c: usize = 0;
        var it = splitByLines(input);
        while (it.next()) |_| : (c += 1) {}
        break :it_blk c;
    };

    if (print_debug) {
        std.debug.print("{d}\n", .{pairs_count});
    }
    const pairs: []Point = try allocator.alloc(Point, pairs_count);
    {
        var i: usize = 0;
        var it = splitByLines(input);
        while (it.next()) |line| : (i += 1) {
            var _i: usize = 0;
            while (_i < line.len and line[_i] != ',') : (_i += 1) {}

            if (print_debug) {
                std.debug.print("line: |{s}|\n", .{line});
            }
            pairs[i].data[0] = try std.fmt.parseInt(u32, line[0.._i], 10);
            pairs[i].data[1] = try std.fmt.parseInt(u32, line[_i + 1 ..], 10);
        }
    }
    return pairs;
}

fn splitByLines(input: []const u8) std.mem.TokenIterator(u8, .scalar) {
    return std.mem.tokenizeScalar(u8, input, '\n');
}
