// SPDX-License-Identifier: BSD-2-Clause
//
// build.zig
//
// Created by:	Aakash Sen Sharma, September 2023
// Copyright:	(C) 2023, Aakash Sen Sharma & Contributors

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zanlib = b.addExecutable(.{
        .name = "zanlib",
        .root_source_file = .{ .path = "zanlib/zanlib.zig" },
        .target = target,
        .optimize = optimize,
    });
    const zar = b.addExecutable(.{
        .name = "zar",
        .root_source_file = .{ .path = "zar/zar.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(zanlib);
    b.installArtifact(zar);
}
