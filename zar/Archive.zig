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
archive_type: ?ArchiveType = null,
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

pub const ParseError = error{
    InvalidArchive,
};

pub const ArchiveType = enum {
    gnu,
    gnu_thin,

    fn getSarmag(self: ArchiveType) usize {
        switch (self) {
            .gnu => {
                return GNUArchive.SARMAG;
            },
            .gnu_thin => {
                return GNUArchiveThin.SARMAG;
            },
        }
    }

    fn getArfmag(self: ArchiveType) []const u8 {
        switch (self) {
            .gnu => {
                return GNUArchive.ARFMAG;
            },
            .gnu_thin => {
                return GNUArchiveThin.ARFMAG;
            },
        }
    }
};

pub fn init(allocator: mem.Allocator, file_name: []const u8) !Self {
    const file = try fs.cwd().openFile(file_name, .{ .mode = .read_write });

    const self: Self = .{
        .file = file,
        .allocator = allocator,
        .archive_header = .{},
    };

    return self;
}

pub fn isValidAr(self: *Self, comptime T: type) bool {
    var magic: [T.SARMAG]u8 = undefined;
    const file_reader = self.file.reader();

    file_reader.readNoEof(&magic) catch return false;

    log.debug("Checking for magic: {s}", .{std.fmt.fmtSliceEscapeLower(T.ARMAG)});
    log.info("Parsed magic string: {s}", .{std.fmt.fmtSliceEscapeLower(&magic)});

    if (!std.mem.eql(u8, &magic, T.ARMAG)) {
        defer self.file.seekTo(0) catch {};
        return false;
    }

    return true;
}

pub fn parse(self: *Self) !void {
    // Parsing archive magic
    self.archive_type = blk: {
        if (self.isValidAr(GNUArchive)) {
            break :blk .gnu;
        }

        if (self.isValidAr(GNUArchiveThin)) {
            break :blk .gnu_thin;
        }
    };

    if (self.archive_type) |_| {} else {
        return ParseError.InvalidArchive;
    }

    const stream = self.file.seekableStream();
    const reader = stream.context.reader();

    while (true or self.archive_type != .invalid) {
        if (try stream.getPos() % 2 != 0) {
            try stream.seekBy(1);
        }

        const archive_header = reader.readStruct(ArchiveHeader) catch break;
        log.debug("{s}", .{std.fmt.fmtSliceEscapeLower(&archive_header.fmag)});

        if (!mem.eql(u8, &archive_header.fmag, self.archive_type.?.getArfmag())) {
            log.debug(
                "invalid header delimiter: expected '{s}', found '{s}'",
                .{ std.fmt.fmtSliceEscapeLower("`\n"), std.fmt.fmtSliceEscapeLower(&archive_header.fmag) },
            );
            return;
        }
    }
}

pub fn deinit(self: *Self) void {
    self.file.close();
}
