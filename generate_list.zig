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

pub fn write_words(
    wordList: *std.ArrayList(Word),
    fileName: []u8,
) !void {
    var file = try std.fs.cwd().createFile(fileName, .{});
    defer file.close();
    var unbufferedWriter = file.writer();
    var bufferedWriter: std.io.BufferedWriter(4096, @TypeOf(unbufferedWriter)) = .{ .unbuffered_writer = unbufferedWriter };
    var writer = bufferedWriter.writer();

    for (wordList.items) |word| {
        _ = try writer.write(&word.word);
        _ = try writer.writeByte('\n');
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

    try stdout.print("Writing valid words\n", .{});
    try write_words(&wordList, args[2]);
}
