const std = @import("std");
const print = std.debug.print;
const WINAPI = @import("std").os.windows.WINAPI;

const win32 = struct {
    usingnamespace @import("zigwin32").zig;
    usingnamespace @import("zigwin32").foundation;
    usingnamespace @import("zigwin32").system.system_services;
    usingnamespace @import("zigwin32").ui.windows_and_messaging;
    usingnamespace @import("zigwin32").system.com;
    usingnamespace @import("zigwin32").graphics.gdi;
    usingnamespace @import("zigwin32").ui.shell;
};

const L = win32.L;

var running: bool = true;

var bitmap_info: win32.BITMAPINFO = std.mem.zeroInit(win32.BITMAPINFO, .{});
var bitmap_memory: ?*?*anyopaque = null;
var bitmap_handle: ?win32.HBITMAP = null;
var bitmap_device_context: ?win32.HDC = null;

/// resizes or initializes a device independent bitmap which is what windows GID can render
fn resize_dib_section(width: i32, height: i32) void {
    // maybe don't free first, free after,  then free first if that fails

    if (bitmap_handle != null) {
        _ = win32.DeleteObject(bitmap_handle);
    }
    if (bitmap_device_context == null) {
        // should we recreate this under special cases?
        bitmap_device_context = win32.CreateCompatibleDC(null);
    }

    bitmap_info.bmiHeader.biSize = @sizeOf(win32.BITMAPINFOHEADER);
    bitmap_info.bmiHeader.biWidth = width;
    bitmap_info.bmiHeader.biHeight = height;
    bitmap_info.bmiHeader.biPlanes = 1;
    bitmap_info.bmiHeader.biBitCount = 32;
    bitmap_info.bmiHeader.biCompression = win32.BI_RGB;

    bitmap_handle = win32.CreateDIBSection(bitmap_device_context, &bitmap_info, win32.DIB_RGB_COLORS, bitmap_memory, null, 0);
}

/// does the window rendering
fn update_window(device_context: ?win32.HDC, x: i32, y: i32, width: i32, height: i32) void {
    _ = win32.StretchDIBits(device_context,
    // dest => the rectagle we are drawing to
    x, y, width, height,
    // src  => the rectangle we are drawing from
    x, y, width, height,
    // the raw bitmap
    @ptrCast(bitmap_memory),
    // tge bitmap info
    &bitmap_info,
    // colors expressed in RGB
    win32.DIB_RGB_COLORS,
    // Only copy colors from src to dest
    win32.SRCCOPY);
}

/// the callback function for windows to send events to
fn WindowProc(window: win32.HWND, message: u32, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(WINAPI) win32.LRESULT {
    var result: win32.LRESULT = 0;
    switch (message) {
        win32.WM_CREATE => {
            print("WM_CREATE\n", .{});
        },
        win32.WM_SIZE => {
            var client_rect = std.mem.zeroInit(win32.RECT, .{});
            _ = win32.GetClientRect(window, &client_rect);
            const width = client_rect.right - client_rect.left;
            const height = client_rect.bottom - client_rect.top;
            resize_dib_section(width, height);
        },
        win32.WM_CLOSE => {
            // TODO: handle this with a message prompt asking if we are sure to quit
            running = false;
        },
        win32.WM_DESTROY => {
            // TODO: handle this as an error. Maybe re-create the window?
            running = false;
        },
        win32.WM_ACTIVATEAPP => {
            print("WM_ACTIVATEAPP\n", .{});
        },
        win32.WM_PAINT => {
            var paint = std.mem.zeroInit(win32.PAINTSTRUCT, .{});
            var device_context = win32.BeginPaint(window, &paint);
            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const height = paint.rcPaint.bottom - paint.rcPaint.top;
            const width = paint.rcPaint.right - paint.rcPaint.left;
            update_window(device_context, x, y, width, height);
            _ = win32.EndPaint(window, &paint);
            print("WM_ACTIVATEAPP\n", .{});
        },
        else => {
            // print("unknown\n", .{});
            result = win32.DefWindowProc(window, message, wparam, lparam);
        },
    }
    return result;
}

/// this is the main function for windows programs
pub export fn wWinMain(instance: win32.HINSTANCE, _previous_instance: ?win32.HINSTANCE, _command_line: [*:0]u16, show_code: u32) callconv(WINAPI) c_int {
    _ = _previous_instance;
    _ = _command_line;
    const hardcoreWindowClass = L("hardcoreWindowClass");
    const wc = win32.WNDCLASS{
        .style = @enumFromInt(0),
        .lpfnWndProc = WindowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = instance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        // TODO: this field is not marked as options so we can't use null atm
        .lpszMenuName = L("Menu"),
        .lpszClassName = hardcoreWindowClass,
    };
    _ = win32.RegisterClass(&wc);
    const hwnd = win32.CreateWindowEx(@enumFromInt(0), // Optional window styles.
        hardcoreWindowClass, // Window class
        L("hardcore"), // Window text
        win32.WS_OVERLAPPEDWINDOW, // Window style
    // Size and position
        win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, win32.CW_USEDEFAULT, null, // Parent window
        null, // Menu
        instance, // Instance handle
        null // Additional application data
    );
    if (hwnd == null) {
        return 0;
        // TODO: log error
    }
    if (win32.ShowWindow(hwnd, @enumFromInt(show_code)) == 0) {
        // TODO: log error
    }
    // Run the message loop.
    var msg: win32.MSG = undefined;
    running = true;
    while (running) {
        var message_result = win32.GetMessage(&msg, null, 0, 0);
        if (message_result == 0) {
            running = false;
            continue;
        } else if (message_result == -1) {
            // TODO: handle error
        }
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessage(&msg);
    }
    return 0;
}
