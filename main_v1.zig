const std = @import("std");

const Word = struct { word: [5]u8, mask: u32, worksWith: *std.ArrayList(usize) };

pub fn load_word_list(alloc: std.mem.Allocator, wordList: *std.ArrayList(Word), fileName: []const u8) !void {
    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();
    var reader = file.reader();

    var buffer: [7]u8 = undefined;
    var line: []u8 = undefined;
    var current: *Word = undefined;
    var mask: u32 = undefined;

    load_loop: while (true) {
        line = reader.readUntilDelimiter(&buffer, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try reader.skipUntilDelimiterOrEof('\n');
                continue :load_loop;
            },
            error.EndOfStream => {
                break :load_loop;
            },
            else => |left_err| return left_err,
        };

        if (line.len != 5 and !(line.len == 6 and line[5] == '\r')) {
            continue :load_loop;
        }

        mask = 0;
        for (line[0..5]) |item| {
            if (item < 'a' or item > 'z') {
                continue :load_loop;
            }

            var shifter: u5 = @truncate(item - 'a');
            var shifted: u32 = @as(u32, 1) << shifter;

            if ((shifted & mask) != 0) {
                continue :load_loop;
            }
            mask |= shifted;
        }

        current = try wordList.*.addOne();
        current.*.word = line[0..5].*; //buffer;
        current.*.mask = mask;
        var array: *std.ArrayList(usize) = try alloc.create(std.ArrayList(usize));
        array.* = std.ArrayList(usize).init(alloc);
        current.worksWith = array;
    }
}

pub fn do_works_with(wordList: *std.ArrayList(Word)) !void {
    for (wordList.*.items, 0..) |a, i| {
        for (wordList.*.items[i + 1 ..], i + 1..) |b, j| {
            if (a.mask & b.mask == 0) {
                try a.worksWith.*.append(j);
                //try b.worksWith.*.append(i);
            }
        }
    }
}

pub fn find_word_recs(wordList: *std.ArrayList(Word), firstWord: *Word, indiciesIn: [5]usize, depth: usize, start: usize, mask: u32, writer: anytype) !void {
    var index: usize = start;
    var indicies: [5]usize = indiciesIn;

    while (index + 4 < firstWord.worksWith.items.len + depth) {
        indicies[depth] = firstWord.worksWith.items[index];

        if (mask & wordList.items[indicies[depth]].mask == 0) {
            if (depth < 4) {
                try find_word_recs(wordList, firstWord, indicies, depth + 1, index + 1, mask | wordList.items[indicies[depth]].mask, writer);
            } else {
                try writer.print("\"{s}\"", .{firstWord.word});
                for (indicies[1..]) |i| {
                    try writer.print(",\"{s}\"", .{wordList.items[i].word});
                }
                try writer.print("\n", .{});
            }
        }

        index += 1;
    }
}

pub fn find_word_combs(wordList: *std.ArrayList(Word), fileName: []u8) !void {
    var indicies: [5]usize = .{ 0, 1, 2, 3, 4 };
    var firstWord: *Word = undefined;

    var file = try std.fs.cwd().createFile(fileName, .{});
    defer file.close();
    var writer = file.writer();

    while (indicies[0] + 4 < wordList.items.len) {
        firstWord = &wordList.items[indicies[0]];

        if (firstWord.worksWith.items.len > 3) {
            try find_word_recs(wordList, firstWord, indicies, 1, 0, firstWord.mask, writer);
        }

        indicies[0] += 1;
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var wordList = std.ArrayList(Word).init(alloc);
    defer wordList.deinit();

    var args = try std.process.argsAlloc(alloc);
    if (args.len < 3) {
        std.debug.print("Needs at least two argument (input and output files)\n", .{});
        return;
    }

    var stdout = std.io.getStdOut().writer();

    try stdout.print("Reading in file\n", .{});
    try load_word_list(alloc, &wordList, args[1]);
    try stdout.print("{} words loaded.\n", .{wordList.items.len});
    if (wordList.items.len < 5) {
        return;
    }

    try stdout.print("Creating Works With Lists.\n", .{});
    try do_works_with(&wordList);

    try stdout.print("Finding Word Combinations\n", .{});
    try find_word_combs(&wordList, args[2]);
}
