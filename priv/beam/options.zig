/// common options utilities functions:
const std = @import("std");
const beam = @import("beam.zig");

pub inline fn allocator(opts: anytype) std.mem.Allocator {
    return if (@hasField(@TypeOf(opts), "allocator")) opts.allocator else beam.context.allocator;
}

pub inline fn env(opts: anytype) beam.env {
    return if (@hasField(@TypeOf(opts), "env")) opts.env else beam.context.env;
}

pub inline fn should_keep(opts: anytype) bool {
    return if (@hasField(@TypeOf(opts), "keep")) opts.keep else true;
}

pub inline fn should_cleanup(opts: anytype) bool {
    return if (@hasField(@TypeOf(opts), "cleanup")) opts.cleanup else true;
}

pub inline fn should_clear(opts: anytype) bool {
    return if (@hasField(@TypeOf(opts), "clear")) opts.clear else false;
}

pub const OutputType = enum { default, list, binary, integer, map };

pub inline fn output(opts: anytype) OutputType {
    comptime { // NB: it's not entirely obvious why this has to be forced into the comptime scope!
        if (!@hasField(@TypeOf(opts), "as")) return .default;

        switch (@typeInfo(@TypeOf(opts.as))) {
            .EnumLiteral => {
                const tag = @tagName(opts.as);
                if (std.mem.eql(u8, tag, "default")) return .default;
                if (std.mem.eql(u8, tag, "list")) return .list;
                if (std.mem.eql(u8, tag, "binary")) return .binary;
                if (std.mem.eql(u8, tag, "integer")) return .integer;
                if (std.mem.eql(u8, tag, "map")) return .map;
                const msg = std.fmt.comptimePrint("invalid `as` EnumLiteral, must be `default`, `list`, `binary`, `integer` or `map`, got: {}.", .{opts.as});
                @compileError(msg);
            },
            .Struct => |S| {
                for (S.fields) |field| {
                    if (std.mem.eql(u8, field.name, "list")) {
                        return .list;
                    }
                    if (std.mem.eql(u8, field.name, "map")) {
                        return .map;
                    }
                }
                @compileError("invalid `as` Struct, must have a field named `list` or `map`");
            },
            else => @compileError("invalid `as` type, must be an EnumLiteral or a Struct"),
        }
    }
}

pub fn assert_default(comptime T: type, opts: anytype) void {
    if (@hasField(@TypeOf(opts), "as")) {
        if (opts.as != .default) {
            const msg = std.fmt.comptimePrint("the 'as' field for the type {} must be `default`", .{T});
            @compileError(msg);
        }
    }
}

fn ListChildOf(T: type) type {
    switch (@typeInfo(T)) {
        .EnumLiteral => {
            return @TypeOf(.default);
        },
        .Struct => |S| {
            inline for (S.fields) |field| {
                if (std.mem.eql(u8, field.name, "list")) return field.type;
                if (std.mem.eql(u8, field.name, "map")) return field.type;
            }
            @compileError("list_child is only callable from a list declaration");
        },
        else => @compileError("the as field must be an enum literal or a tuple.")
    }
}

pub fn list_child(list_as: anytype) ListChildOf(@TypeOf(list_as)) {
    const T = @TypeOf(list_as);
    switch (@typeInfo(T)) {
        .EnumLiteral => return .default,
        .Struct => return list_as.list,
        else => unreachable,
    }
}
