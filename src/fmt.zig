const std = @import("std");
const heap = std.heap;
const mem = std.mem;
const zig = std.zig;

fn getJsonObject(allocator: *std.mem.Allocator) !std.json.Value {
    var value = std.json.Value{ .Object = std.json.ObjectMap.init(allocator) };
    _ = try value.Object.put("one", std.json.Value{ .Integer = @intCast(i64, 1) });
    _ = try value.Object.put("two", std.json.Value{ .Float = 2.0 });
    return value;
}

/// Expose a print function to Javascript.
/// The extern keyword can be used to link against a variable that is exported from another object.
/// https://webassembly.github.io/spec/core/syntax/types.html
extern fn print(i32) void;

/// Write a test JSON file
/// https://github.com/ziglang/zig/blob/25ec2dbc1e2302d1138749262b588d3e438fcd55/lib/std/json/write_stream.zig#L238
fn writeJson(allocator: *mem.Allocator, source: []const u8) ![]u8 {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out_stream = slice_stream.outStream();

    var w = std.json.writeStream(out_stream, 10);
    try w.beginObject();
    try w.objectField("object");
    try w.emitJson(try getJsonObject(allocator));
    try w.objectField("string");
    try w.emitString("This is a string");
    try w.objectField("array");
    try w.beginArray();
    try w.arrayElem();
    try w.emitString("Another string");
    try w.arrayElem();
    try w.emitNumber(@as(i32, 1));
    try w.arrayElem();
    try w.emitNumber(@as(f32, 3.5));
    try w.endArray();
    try w.objectField("int");
    try w.emitNumber(@as(i32, 10));
    try w.objectField("float");
    try w.emitNumber(@as(f32, 3.5));
    try w.endObject();

    return slice_stream.getWritten();
}

/// Format zig `source` code with zig-fmt
/// https://github.com/ziglang/zig/blob/4a69b11e742365d68e4d92aa18d6493db9d3edaf/lib/std/io/fixed_buffer_stream.zig#L145
fn format(allocator: *mem.Allocator, source: []const u8) ![]u8 {
    // parse input source code and create the abstract syntax tree
    const tree = try zig.parse(allocator, source);
    defer tree.deinit();

    if (tree.errors.len != 0) {
        return error.ParseError;
    }

    var buf: [1024]u8 = undefined;
    print(buf.len);
    var fbs = std.io.fixedBufferStream(&buf);
    const out_stream = fbs.writer(); // fbs.outStream() is the same but it's deprecated

    const changed = try zig.render(allocator, out_stream, tree);
    // changed is true if the formatted code written to `out_stream` is the same
    // as the the input `source` code. Otherwise changed is false.

    // try out_stream.writeAll("Ciao ");
    // try out_stream.print("{} {}!", .{ "Hello", "World" });
    // try out_stream.writeAll(" Mondo");

    return fbs.getWritten();
}

export fn format_export(input_ptr: [*]const u8, input_len: usize, output_ptr: *[*]u8, output_len: *usize) bool {
    const input = input_ptr[0..input_len];

    var output = format(std.heap.page_allocator, input) catch |err| {
        std.debug.assert(err == error.ParseError);
        return false;
    };

    // another example
    // var gpa = heap.GeneralPurposeAllocator(.{}){};
    // var output = writeJson(&gpa.allocator, input) catch |err| {
    //     return false;
    // };

    output_ptr.* = output.ptr;
    output_len.* = output.len;
    return true;
}

export fn _wasm_alloc(len: usize) u32 {
    var buf = heap.page_allocator.alloc(u8, len) catch |err| return 0;
    return @ptrToInt(buf.ptr);
}

export fn _wasm_dealloc(ptr: [*]const u8, len: usize) void {
    heap.page_allocator.free(ptr[0..len]);
}
