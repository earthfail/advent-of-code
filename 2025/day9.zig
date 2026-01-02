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
    // if (!test_binary_search()) {
    //     return error.Fail;
    // }
}

const Index = u16;

const Point = struct {
    data: [2]u32,

    const XY = enum(u8) { X = 0, Y = 1 };
    pub fn ref(self: *Point, axis: XY) *u32 {
        return &self.data[@intFromEnum(axis)];
    }
    pub fn refc(self: Point, axis: XY) u32 {
        return self.data[@intFromEnum(axis)];
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
    const poly_lines_buff = try allocator.alloc(Index, pairs.len);
    // poly_lines[axis] stores contour lines parallel to axis.
    // to use the cache, we only store the index of the first point in the line
    // as stored in pairs list.
    const poly_lines: [2][]Index = .{ poly_lines_buff[0..len2], poly_lines_buff[len2..] };
    assert(poly_lines[0].len == len2);
    assert(poly_lines[1].len == len2);
    {
        var idx: [2]Index = .{ 0, 0 };
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
    }
    var ctx: Context = undefined;
    ctx.list = pairs;
    for (0..2) |axis| {
        ctx.axis = @enumFromInt(axis);
        std.mem.sort(Index, poly_lines[axis], ctx, lessThanLine);
    }

    var max: u64 = 0;
    for (0..pairs.len - 1) |i| {
        rect_label: for (i + 1..pairs.len) |j| {
            if (print_debug) {
                std.debug.print("candidates {any}, {any}\n", .{ pairs[i].data, pairs[j].data });
            }
            for (0..2) |axis| {
                ctx.axis = @enumFromInt(axis);
                ctx.lower_bound = @min(pairs[i].data[axis], pairs[j].data[axis]);
                ctx.upper_bound = @max(pairs[i].data[axis], pairs[j].data[axis]);

                if (binarySearchRange(Index, poly_lines[axis], ctx, compareRange)) |range| {
                    if (print_debug) {
                        std.debug.print("testing {any} axis {}\n", .{ poly_lines[axis][range[0] .. range[1] + 1], ctx.axis });
                    }
                    for (poly_lines[axis][range[0] .. range[1] + 1]) |index| {
                        if (lineIntersectRect(pairs, index, @intCast(i), @intCast(j))) {
                            continue :rect_label;
                        }
                    }
                }
            }
            const area = calcArea(pairs[i], pairs[j]);
            if (print_debug) {
                std.debug.print("calc area between {any}, {any} = {}\n", .{ pairs[i].data, pairs[j].data, area });
            }
            max = @max(max, area);
        }
    }
    std.debug.print("max: {d}\n", .{max});
    // std.mem.sort(Point, pairs, {}, lessThanFn);
    // assert(IsSortedByX(pairs));
}

// this is an amalgamation to XY \cup u32xu32
// use XY for sorting
// use lower,upper bounds for binary search
const Context = struct {
    list: []const Point,
    axis: Point.XY,
    lower_bound: u32 = 0,
    upper_bound: u32 = math.maxInt(u32),
};

fn lessThanLine(ctx: Context, lhs: Index, rhs: Index) bool {
    return ctx.list[lhs].data[@intFromEnum(ctx.axis)] < ctx.list[rhs].data[@intFromEnum(ctx.axis)];
}

fn compareRange(ctx: Context, idx: Index) math.Order {
    // assert(ctx.lower_bound <= ctx.upper_bound);
    const v = ctx.list[idx].refc(ctx.axis);
    if (ctx.lower_bound < v and v < ctx.upper_bound)
        return .eq;
    if (ctx.upper_bound <= v)
        return .gt;
    return .lt;
}

// assume items is sorted. returns range of all values that are math.Order.eq
// can be used to find a range
// it is not necessary to be this general in this case.
fn binarySearchRange(
    comptime T: type,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (@TypeOf(context), T) std.math.Order,
) ?[2]usize {
    var range: [2]usize = .{ 0, items.len - 1 };
    // first finding the leftmost equal
    var L: usize, var R: usize = range;
    var M: usize = undefined;
    while (L < R) {
        M = L + (R - L) / 2;
        switch (compareFn(context, items[M])) {
            .lt => L = M + 1,
            .gt, .eq => R = M,
        }
    }
    if (compareFn(context, items[L]) != .eq) {
        return null;
    }
    range[0] = L;

    L, R = .{ 0, items.len };
    while (L < R) {
        M = L + (R - L) / 2;
        switch (compareFn(context, items[M])) {
            .lt, .eq => L = M + 1,
            .gt => R = M,
        }
    }
    if (R == 0 or compareFn(context, items[R - 1]) != .eq) {
        return null;
    }
    range[1] = R - 1;

    // we could also use the fact that P => Q \equiv ~P \/ Q
    assert(if (range[0] > 0) compareFn(context, items[range[0] - 1]) == .lt else true);
    assert(if (range[1] < items.len - 1) compareFn(context, items[range[1] + 1]) == .gt else true);
    return range;
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

fn lineIntersectRect(pairs: []const Point, line_start: Index, rect_edge1: Index, rect_edge2: Index) bool {
    const line_end = (line_start + 1) % pairs.len;
    const axis: Point.XY = if (pairs[line_start].x() == pairs[line_end].x()) .X else .Y;

    // assume the line in the axis it is parallel to is in range of the rect.
    assert(blk: {
        const x = pairs[line_start].refc(axis);
        const mi = @min(pairs[rect_edge1].refc(axis), pairs[rect_edge2].refc(axis));
        const ma = @max(pairs[rect_edge1].refc(axis), pairs[rect_edge2].refc(axis));
        break :blk x > mi and x < ma;
    });

    const other_axis: Point.XY = if (axis == .X) .Y else .X;
    const line_range: [2]u32 = orderValues(pairs[line_start].refc(other_axis), pairs[line_end].refc(other_axis));

    const rect_range: [2]u32 = orderValues(pairs[rect_edge1].refc(other_axis), pairs[rect_edge2].refc(other_axis));

    // [a,b) does not intersect [c,d) iff
    //             a.....b
    //                   c.......d
    //
    // or         c.......d
    //                    a.....b
    return !(line_range[1] <= rect_range[0] or rect_range[1] <= line_range[0]);
}

fn orderValues(a: u32, b: u32) [2]u32 {
    return .{ @min(a, b), @max(a, b) };
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

fn test_binary_search() bool {
    const Box = struct {
        v: i32,
        fn compareFn(b: @This(), x: i32) std.math.Order {
            const v: i32 = b.v;
            // const v: i32 = 100;
            const ord = math.order(x, v);
            if (print_debug) {
                std.debug.print("{} {} {}\n", .{ x, ord, v });
            }
            return ord;
        }
    };
    const items = &[_]i32{ 0, 10, 20, 30, 40, 50, 60, 70, 80 };
    const vs = &[_]i32{ -10, 0, 5, 15, 20, 40, 75, 80, 90 };
    var b: Box = undefined;
    if (print_debug) {
        std.debug.print("items {any}\n", .{items});
    }
    if (true) {
        for (vs) |v| {
            b.v = v;
            const res = binarySearchRange(i32, items, b, Box.compareFn);
            if (res) |r|
                if (r[0] != r[1]) {
                    std.debug.print("finding {} got two answers {any}\n", .{ v, r });
                    return false;
                };

            var res_lin: ?usize = null;
            for (0..items.len) |i| {
                if (items[i] == v)
                    res_lin = i;
            }
            if (print_debug) {
                std.debug.print("{} => res {?any}\n", .{ v, res });
            }

            if ((res == null and res_lin != null) or (res != null and res_lin == null) or (res != null and res_lin != null and res.?[0] != res_lin.?)) {
                std.debug.print("finding {} failed got {?any} expected {?any}\n", .{ v, res, res_lin });
                return false;
            }
        }
    }
    const Range = struct {
        a: i32,
        b: i32,
        fn compareFn(t: @This(), x: i32) std.math.Order {
            assert(t.a <= t.b);
            if (x > t.a and x < t.b)
                return .eq;
            if (x >= t.b)
                return .gt;
            if (x <= t.a)
                return .lt;
            unreachable;
        }
    };
    const rs = &[_]Range{ .{ .a = -10, .b = 10 }, .{ .a = -10, .b = 0 }, .{ .a = 11, .b = 60 }, .{ .a = -1, .b = 100 }, .{ .a = 65, .b = 85 }, .{ .a = 80, .b = 1000 } };
    if (true) {
        for (rs) |r| {
            const res = binarySearchRange(i32, items, r, Range.compareFn);
            var res_lin: ?[2]usize = null;
            for (0..items.len) |i| {
                if (items[i] > r.a and items[i] < r.b) {
                    if (res_lin) |*lin| {
                        lin[1] = i;
                    } else res_lin = .{ i, i };
                }
            }
            if (print_debug) {
                std.debug.print("({},{}) => res {?any}\n", .{ r.a, r.b, res });
            }
            if (res == null and res_lin == null)
                continue;
            if (res != null and res_lin != null and res.?[0] == res_lin.?[0] and res.?[1] == res_lin.?[1])
                continue;

            std.debug.print("finding ({},{}) failed got {?any} expected {?any}\n", .{ r.a, r.b, res, res_lin });
            return false;
        }
    }
    return true;
}
