// SPDX-License-Identifier: BSD-2-Clause
//
// zar/zar.zig
//
// Created by:	Aakash Sen Sharma, September 2023
// Copyright:	(C) 2023, Aakash Sen Sharma & Contributors

const std = @import("std");
const Archive = @import("Archive.zig");
const log = std.log.scoped(.Zar);
const os = std.os;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var args = std.process.args();
    _ = args.skip();

    const file_name = args.next() orelse return error.FileNameNotSpecified;

    var archive = try Archive.init(allocator, file_name);
    defer archive.deinit();

    try archive.parse();

    log.debug("Archive type: {s}\n", .{@tagName(archive.archive_type.?)});
}
