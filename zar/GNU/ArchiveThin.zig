// SPDX-License-Identifier: BSD-2-Clause
//
// zar/GNU/ArchiveThin.zig
//
// Created by:	Aakash Sen Sharma, September 2023
// Copyright:	(C) 2023, Aakash Sen Sharma & Contributors

const Self = @This();

pub const SARMAG: u4 = 8;
pub const ARMAG: *const [SARMAG:0]u8 = "!<thin>\n";

pub const ARFMAG: *const [2:0]u8 = "`\n";
pub const SYM64NAME: *const [7:0]u8 = "/SYM64/";
