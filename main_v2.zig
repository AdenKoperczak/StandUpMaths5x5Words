const std = @import("std");

const Word = struct { word: [5]u8, mask: u32, worksWith: *std.ArrayList(*Word) };

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
        var array: *std.ArrayList(*Word) = try alloc.create(std.ArrayList(*Word));
        array.* = std.ArrayList(*Word).init(alloc);
        current.worksWith = array;
    }
}

pub fn do_works_with(wordList: *std.ArrayList(Word)) !void {
    for (wordList.items, 0..) |a, i| {
        for (wordList.items[i + 1 ..], i + 1..) |b, j| {
            if (a.mask & b.mask == 0) {
                try a.worksWith.append(&wordList.items[j]);
            }
        }
    }
}

pub fn find_word_recs(words: *[5]*Word, depth: usize, start: usize, mask: u32, writer: anytype) !void {
    var index: usize = start;

    while (index + 4 < words[0].worksWith.items.len + depth) {
        words[depth] = words[0].worksWith.items[index];

        if (mask & words[depth].mask == 0) {
            if (depth < 4) {
                try find_word_recs(words, depth + 1, index + 1, mask | words[depth].mask, writer);
            } else {
                try writer.print("\"{s}\"", .{words[0].word});
                for (words[1..]) |word| {
                    try writer.print(",\"{s}\"", .{word.word});
                }
                try writer.print("\n", .{});
            }
        }

        index += 1;
    }
}

pub fn find_word_combs(wordList: *std.ArrayList(Word), fileName: []u8) !void {
    var words: [5]*Word = undefined;

    var file = try std.fs.cwd().createFile(fileName, .{});
    defer file.close();
    var writer = file.writer();

    var index: usize = 0;

    while (index + 4 < wordList.items.len) {
        words[0] = &wordList.items[index];

        if (words[0].worksWith.items.len > 3) {
            try find_word_recs(&words, 1, 0, words[0].mask, writer);
        }

        index += 1;
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
