const std = @import("std");
const ZIG_11 = @import("builtin").zig_version.minor >= 11;

const Word = struct {
    word: [5]u8,
    mask: u32,
};

const WordStack = struct {
    words: []*Word,
    size: usize,
    totalSize: usize,

    pub fn init(alloc: std.mem.Allocator, size: usize) !WordStack {
        var arr = try alloc.alloc(*Word, size);

        return WordStack{
            .words = arr,
            .size = 0,
            .totalSize = size,
        };
    }

    pub fn add(self: *WordStack, word: *Word) void {
        self.words[self.size] = word;
        self.size += 1;
    }

    pub fn clear(self: *WordStack) void {
        self.size = 0;
    }
};

pub fn load_word_list(
    wordList: *std.ArrayList(Word),
    fileName: []const u8,
) !void {
    var file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    const length = try file.getEndPos();
    if (length < 5) {
        return;
    }

    const ptr = if (ZIG_11)
        try std.os.mmap(
            null,
            length,
            std.os.PROT.READ | std.os.PROT.WRITE,
            std.os.MAP.PRIVATE,
            file.handle,
            0,
        )
    else
        try std.posix.mmap(
            null,
            length,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE },
            file.handle,
            0,
        );

    defer if (ZIG_11) {
        std.os.munmap(ptr);
    } else {
        defer std.posix.munmap(ptr);
    };

    var line: [5]u8 = undefined;
    var mask: u32 = undefined;
    var pos: usize = 0;
    var tmp: u8 = undefined;
    var current: *Word = undefined;

    load_loop: while (pos + 4 < length) {
        mask = 0;

        if (pos + 5 < length and ptr[pos + 5] != '\r' and ptr[pos + 5] != '\n') {
            while (pos < length and ptr[pos] != '\n') {
                pos += 1;
            }
            pos += 1;
            continue :load_loop;
        }

        for (0..5) |i| {
            tmp = ptr[pos];

            if (tmp < 'a' or tmp > 'z') {
                while (pos < length and ptr[pos] != '\n') {
                    pos += 1;
                }
                pos += 1;
                continue :load_loop;
            }

            var shifter: u5 = @truncate(tmp - 'a');
            var shifted: u32 = @as(u32, 1) << shifter;
            if (mask & shifted != 0) {
                while (pos < length and ptr[pos] != '\n') {
                    pos += 1;
                }
                pos += 1;
                continue :load_loop;
            }

            mask |= shifted;
            line[i] = tmp;
            pos += 1;
        }
        pos += 1;

        current = try wordList.addOne();
        current.word = line;
        current.mask = mask;
    }
}

pub fn find_word_recs(
    words: *[4]*Word,
    working: *[4]WordStack,
    depth: usize,
    writer: anytype,
) !void {
    var index: usize = 0;

    if (depth == 4) {
        for (0..working[depth - 1].size) |i| {
            for (words) |word| {
                //try writer.print("\"{s}\",", .{word.word});
                _ = try writer.write("\"");
                _ = try writer.write(&word.word);
                _ = try writer.write("\",");
            }

            //try writer.print("\"{s}\"\n", .{working[depth - 1][i].word});
            _ = try writer.write("\"");
            _ = try writer.write(&working[depth - 1].words[i].word);
            _ = try writer.write("\"\n");
        }

        return;
    }

    while (index + 4 < working[depth - 1].size + depth) {
        words[depth] = working[depth - 1].words[index];
        working[depth].clear();

        for (index + 1..working[depth - 1].size) |i| {
            if (working[depth - 1].words[i].mask & words[depth].mask == 0) {
                working[depth].add(working[depth - 1].words[i]);
            }
        }

        try find_word_recs(words, working, depth + 1, writer);

        index += 1;
    }
}

pub fn find_word_combs(
    alloc: std.mem.Allocator,
    wordList: *std.ArrayList(Word),
    fileName: []u8,
) !void {
    var words: [4]*Word = undefined;
    var working: [4]WordStack = undefined;

    for (0..working.len) |i| {
        working[i] = try WordStack.init(alloc, wordList.items.len);
    }

    var file = try std.fs.cwd().createFile(fileName, .{});
    defer file.close();
    var unbufferedWriter = file.writer();
    // buffer for each line. IDK if this helps
    var bufferedWriter: std.io.BufferedWriter(5 * (5 + 2 + 1), @TypeOf(unbufferedWriter)) = .{ .unbuffered_writer = unbufferedWriter };
    var writer = bufferedWriter.writer();

    var index: usize = 0;

    while (index + 4 < wordList.items.len) {
        words[0] = &wordList.items[index];
        working[0].clear();

        for (index + 1..wordList.items.len) |i| {
            if (words[0].mask & wordList.items[i].mask == 0) {
                working[0].add(&wordList.items[i]);
            }
        }

        try find_word_recs(&words, &working, 1, writer);

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
