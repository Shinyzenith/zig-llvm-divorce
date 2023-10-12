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
file_contents: []const u8,

archive_type: ?ArchiveType = null,
strtab: []const u8 = undefined,

pub const ArchiveHeader = extern struct {
    name: [16]u8 = undefined,
    date: [12]u8 = undefined,
    uid: [6]u8 = undefined,
    gid: [6]u8 = undefined,
    mode: [8]u8 = undefined,
    size: [10]u8 = undefined,
    fmag: [2]u8 = undefined,

    pub fn getValue(raw_str: []const u8) []const u8 {
        return mem.trimRight(u8, raw_str, " ");
    }

    pub fn getSize(self: ArchiveHeader) !u32 {
        const value = getValue(&self.size);
        return std.fmt.parseInt(u32, value, 10);
    }

    pub fn isStrtab(self: ArchiveHeader) bool {
        return mem.eql(u8, getValue(&self.name), "//");
    }

    pub fn isSymtab(self: ArchiveHeader) bool {
        return mem.eql(u8, getValue(&self.name), "/");
    }
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
    const file_stat = try file.stat();
    const file_contents = try file.readToEndAlloc(allocator, file_stat.size);
    defer file.seekTo(0) catch {};

    const self: Self = .{
        .allocator = allocator,
        .file = file,
        .file_contents = file_contents,
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

    while (true) {
        if (try stream.getPos() % 2 != 0) {
            try stream.seekBy(1);
        }

        const archive_header = reader.readStruct(ArchiveHeader) catch break;
        const archive_name = ArchiveHeader.getValue(&archive_header.name);
        log.debug("Header info:\n\tname: {s}\n\tfmag: {s}\n\tsize: {d}\n\tisStrtab: {d}\n\tisSymtab: {d}", .{
            archive_header.name,
            std.fmt.fmtSliceEscapeLower(&archive_header.fmag),
            try archive_header.getSize(),
            @intFromBool(archive_header.isStrtab()),
            @intFromBool(archive_header.isSymtab()),
        });

        if (!mem.eql(u8, &archive_header.fmag, self.archive_type.?.getArfmag())) {
            log.debug(
                "invalid header delimiter: expected '{s}', found '{s}'",
                .{ std.fmt.fmtSliceEscapeLower("`\n"), std.fmt.fmtSliceEscapeLower(&archive_header.fmag) },
            );
            return;
        }

        const archive_header_size = try archive_header.getSize();
        defer _ = stream.seekBy(archive_header_size) catch {};

        if (archive_header.isSymtab()) continue;
        if (archive_header.isStrtab()) {
            const current_position = try stream.getPos();
            self.strtab = self.file_contents[current_position..][0..archive_header_size];
            continue;
        }
        if (mem.eql(u8, archive_name, "__.SYMDEF") or mem.eql(u8, archive_name, "__.SYMDEF SORTED")) continue;

        const object_file_name = blk: {
            if (archive_name[0] == '/') {
                log.debug("Object file name is greater than 15. Resolving string table offset.", .{});
                const offset = try std.fmt.parseInt(u32, archive_name[1..], 10);
                break :blk self.getString(offset);
            }

            break :blk archive_name;
        };
        log.debug("Object file name: {s}", .{object_file_name});
    }
}

fn getString(self: *Self, offset: u32) []const u8 {
    std.debug.assert(offset < self.strtab.len);
    return mem.sliceTo(@as([*:'\n']const u8, @ptrCast(self.strtab.ptr + offset)), '\n');
}

pub fn deinit(self: *Self) void {
    self.file.close();
    self.allocator.free(self.file_contents);
}
