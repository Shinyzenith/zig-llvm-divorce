// SPDX-License-Identifier: BSD-2-Clause
//
// zar/Archive.zig
//
// Created by:	Aakash Sen Sharma, September 2023
// Copyright:	(C) 2023, Aakash Sen Sharma & Contributors

const Self = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.Archive);

pub const GNUArchive = @import("GNU/Archive.zig");
pub const GNUArchiveThin = @import("GNU/ArchiveThin.zig");

allocator: mem.Allocator,
file: fs.File,
file_reader: fs.File.Reader,
data: []const u8 = undefined,
archive_type: ArchiveType = .invalid,
archive_header: ArchiveHeader,

pub const ArchiveHeader = extern struct {
    name: [16]u8 = undefined,
    date: [12]u8 = undefined,
    uid: [6]u8 = undefined,
    gid: [6]u8 = undefined,
    mode: [8]u8 = undefined,
    size: [10]u8 = undefined,
    fmag: [2]u8 = undefined,
};

pub const ArchiveType = enum {
    gnu,
    gnu_thin,
    invalid,
};

pub fn init(allocator: mem.Allocator, file_name: []const u8) !Self {
    const file = try fs.cwd().openFile(file_name, .{ .mode = .read_write });
    const file_stat = try file.stat();

    const file_data = try file.readToEndAlloc(allocator, file_stat.size);
    try file.seekTo(0);

    const self: Self = .{
        .file = file,
        .file_reader = file.reader(),
        .allocator = allocator,
        .data = file_data,
        .archive_header = .{},
    };

    return self;
}

pub fn isValidAr(self: *Self, comptime T: type) bool {
    var magic: [T.SARMAG]u8 = undefined;
    self.file_reader.readNoEof(&magic) catch return false;

    //std.fmt.fmtSliceEscapeLower(
    log.debug("Checking for magic: {s}", .{std.fmt.fmtSliceEscapeLower(T.ARMAG)});
    log.info("Parsed magic string: {s}", .{std.fmt.fmtSliceEscapeLower(&magic)});

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

    var stream = std.io.fixedBufferStream(self.data);
    const reader = stream.reader();

    //TODO: Un-hardcode me pls.
    _ = reader.readBytesNoEof(GNUArchive.SARMAG) catch {};
    while (true or self.archive_type != .invalid) {
        if (stream.pos % 2 != 0) {
            stream.pos += 1;
        }

        const archive_header = reader.readStruct(ArchiveHeader) catch break;
        log.debug("{s}", .{std.fmt.fmtSliceEscapeLower(&archive_header.fmag)});

        //TODO: Un-hardcode me pls.
        if (!mem.eql(u8, &archive_header.fmag, GNUArchive.ARFMAG)) {
            log.debug(
                "invalid header delimiter: expected '{s}', found '{s}'",
                .{ std.fmt.fmtSliceEscapeLower("`\n"), std.fmt.fmtSliceEscapeLower(&archive_header.fmag) },
            );
            return;
        }
    }
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.data);
    self.file.close();
}
