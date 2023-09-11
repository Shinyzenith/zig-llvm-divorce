// SPDX-License-Identifier: BSD-2-Clause
//
// zar/Archive.zig
//
// Created by:	Aakash Sen Sharma, September 2023
// Copyright:	(C) 2023, Aakash Sen Sharma & Contributors

const Self = @This();

const std = @import("std");
const fs = std.fs;
const log = std.log.scoped(.Archive);

pub const GNUArchive = @import("GNU/Archive.zig");
pub const GNUArchiveThin = @import("GNU/ArchiveThin.zig");

file: fs.File,
file_reader: fs.File.Reader,

archive_type: ArchiveType = .invalid,

name: [16]u8 = undefined,
date: [12]u8 = undefined,
uid: [6]u8 = undefined,
gid: [6]u8 = undefined,
mode: [8]u8 = undefined,
size: [10]u8 = undefined,
fmag: [2]u8 = undefined,

pub const ArchiveType = enum {
    gnu,
    gnu_thin,
    invalid,
};

pub fn init(file_name: []const u8) fs.File.OpenError!Self {
    const file = try fs.cwd().openFile(file_name, .{ .mode = .read_write });
    const reader = file.reader();

    const self: Self = .{
        .file = file,
        .file_reader = reader,
    };

    return self;
}

pub fn isValidAr(self: *Self, comptime T: type) bool {
    var magic: [T.SARMAG]u8 = undefined;
    self.file_reader.readNoEof(&magic) catch return false;

    log.debug("Checking for magic: {s}", .{T.ARMAG});
    log.info("Parsed magic string: {s}", .{magic});

    if (!std.mem.eql(u8, &magic, T.ARMAG)) {
        self.file.seekTo(0) catch {};
        return false;
    }

    return true;
}

pub fn parse(self: *Self) void {
    // Parsing archive magic
    self.archive_type = blk: {
        if (self.isValidAr(GNUArchive)) {
            break :blk .gnu;
        }

        if (self.isValidAr(GNUArchiveThin)) {
            break :blk .gnu_thin;
        }
    };
}

pub fn deinit(self: *Self) void {
    self.file.close();
}
