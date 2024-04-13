const std = @import("std");

const Word = struct { word: [5]u8, mask: u32 };

pub fn load_word_list(
    wordList: *std.ArrayList(Word),
    fileName: []const u8,
) !void {
    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();
    var unbufferedReader = file.reader();
    var bufferedReader: std.io.BufferedReader(4096, @TypeOf(unbufferedReader)) = .{ .unbuffered_reader = unbufferedReader };
    var reader = bufferedReader.reader();

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

        current = try wordList.addOne();
        current.word = line[0..5].*;
        current.mask = mask;
    }
}

pub fn find_word_recs(
    words: *[4]*Word,
    working: *[4][]*Word,
    workingLen: *[4]usize,
    depth: usize,
    writer: anytype,
) !void {
    var index: usize = 0;

    if (depth == 4) {
        for (0..workingLen[depth - 1]) |i| {
            for (words) |word| {
                //try writer.print("\"{s}\",", .{word.word});
                _ = try writer.write("\"");
                _ = try writer.write(&word.word);
                _ = try writer.write("\",");
            }

            //try writer.print("\"{s}\"\n", .{working[depth - 1][i].word});
            _ = try writer.write("\"");
            _ = try writer.write(&working[depth - 1][i].word);
            _ = try writer.write("\"\n");
        }

        return;
    }

    while (index + 4 < workingLen[depth - 1] + depth) {
        words[depth] = working[depth - 1][index];
        workingLen[depth] = 0;

        for (index + 1..workingLen[depth - 1]) |i| {
            if (working[depth - 1][i].mask & words[depth].mask == 0) {
                working[depth][workingLen[depth]] = working[depth - 1][i];
                workingLen[depth] += 1;
            }
        }

        try find_word_recs(words, working, workingLen, depth + 1, writer);

        index += 1;
    }
}

pub fn find_word_combs(
    alloc: std.mem.Allocator,
    wordList: *std.ArrayList(Word),
    fileName: []u8,
) !void {
    var words: [4]*Word = undefined;
    var working: [4][]*Word = undefined;
    var workingLen: [4]usize = undefined;

    for (0..working.len) |i| {
        working[i] = try alloc.alloc(*Word, wordList.items.len);
    }

    var file = try std.fs.cwd().createFile(fileName, .{});
    defer file.close();
    var unbufferedWriter = file.writer();
    var bufferedWriter: std.io.BufferedWriter(128, @TypeOf(unbufferedWriter)) = .{ .unbuffered_writer = unbufferedWriter };
    var writer = bufferedWriter.writer();

    var index: usize = 0;

    while (index + 4 < wordList.items.len) {
        words[0] = &wordList.items[index];
        workingLen[0] = 0;

        for (index + 1..wordList.items.len) |i| {
            if (words[0].mask & wordList.items[i].mask == 0) {
                working[0][workingLen[0]] = &wordList.items[i];
                workingLen[0] += 1;
            }
        }

        try find_word_recs(&words, &working, &workingLen, 1, writer);

        index += 1;
    }

    try bufferedWriter.flush();
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
    try load_word_list(&wordList, args[1]);
    try stdout.print("{} words loaded.\n", .{wordList.items.len});
    if (wordList.items.len < 5) {
        return;
    }

    try stdout.print("Finding Word Combinations\n", .{});
    try find_word_combs(alloc, &wordList, args[2]);
}
