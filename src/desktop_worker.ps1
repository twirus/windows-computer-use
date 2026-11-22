$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName WindowsBase

$csharp = @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Forms;

public static class DesktopNative {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    public static extern uint MapVirtualKey(uint uCode, uint uMapType);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    public static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP = 0x0010;
    public const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    public const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
    public const uint MOUSEEVENTF_WHEEL = 0x0800;

    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint KEYEVENTF_UNICODE = 0x0004;

    public const int SW_MAXIMIZE = 3;
    public const int SW_SHOW = 5;
    public const int SW_MINIMIZE = 6;
    public const int SW_RESTORE = 9;
    public const int SM_CXSCREEN = 0;
    public const int SM_CYSCREEN = 1;
    public const uint WM_CLOSE = 0x0010;

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public uint type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    public class WindowInfo {
        public long Handle;
        public int Pid;
        public string ProcessName;
        public string Title;
        public int X;
        public int Y;
        public int Width;
        public int Height;
        public bool IsForeground;
        public bool IsMinimized;
    }

    public class UiElementInfo {
        public int Id;
        public string Type;
        public string Name;
        public string Value;
        public int X;
        public int Y;
        public int Width;
        public int Height;
        public int Cx;
        public int Cy;
        public long WindowHandle;
    }

    public class ScreenshotResult {
        public int OriginX;
        public int OriginY;
        public int ScreenWidth;
        public int ScreenHeight;
        public int ImageWidth;
        public int ImageHeight;
        public string PngBase64;
    }

    public class DesktopStateResult {
        public int OriginX;
        public int OriginY;
        public int ScreenWidth;
        public int ScreenHeight;
        public int ImageWidth;
        public int ImageHeight;
        public int CursorX;
        public int CursorY;
        public WindowInfo ActiveWindow;
        public List<WindowInfo> Windows;
        public List<UiElementInfo> Elements;
        public string PngBase64;
        public bool Truncated;
    }

    public static Dictionary<int, UiElementInfo> LastElements = new Dictionary<int, UiElementInfo>();

    public static void InitDpi() {
        try {
            SetProcessDpiAwarenessContext(new IntPtr(-4));
        } catch {
            try { SetProcessDPIAware(); } catch { }
        }
    }

    public static POINT GetCursor() {
        POINT p;
        GetCursorPos(out p);
        return p;
    }

    public static List<WindowInfo> ListWindows() {
        List<WindowInfo> list = new List<WindowInfo>();
        IntPtr fg = GetForegroundWindow();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (!IsWindowVisible(hWnd)) return true;
            int len = GetWindowTextLength(hWnd);
            if (len <= 0) return true;
            StringBuilder sb = new StringBuilder(len + 1);
            GetWindowText(hWnd, sb, sb.Capacity);
            string title = sb.ToString().Trim();
            if (string.IsNullOrEmpty(title)) return true;

            RECT r;
            if (!GetWindowRect(hWnd, out r)) return true;
            int w = r.Right - r.Left;
            int h = r.Bottom - r.Top;
            if (w <= 20 || h <= 20) return true;

            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            string procName = "";
            try {
                Process p = Process.GetProcessById((int)pid);
                procName = p.ProcessName;
            } catch { }

            WindowInfo wi = new WindowInfo();
            wi.Handle = hWnd.ToInt64();
            wi.Pid = (int)pid;
            wi.ProcessName = procName;
            wi.Title = title;
            wi.X = r.Left;
            wi.Y = r.Top;
            wi.Width = w;
            wi.Height = h;
            wi.IsForeground = (hWnd == fg);
            wi.IsMinimized = IsIconic(hWnd);
            list.Add(wi);
            return true;
        }, IntPtr.Zero);
        return list;
    }

    public static bool FocusWindow(IntPtr hWnd) {
        if (hWnd == IntPtr.Zero) return false;
        if (GetForegroundWindow() == hWnd) return true;
        if (IsIconic(hWnd)) {
            ShowWindowAsync(hWnd, SW_RESTORE);
            Thread.Sleep(80);
        }
        try {
            SwitchToThisWindow(hWnd, true);
        } catch { }
        SetForegroundWindow(hWnd);
        Thread.Sleep(80);
        if (GetForegroundWindow() != hWnd) {
            // Safe Alt tap trick without AttachThreadInput (never hides/crashes Electron/Discord)
            SendKeyCombo(new ushort[] { 0x12 });
            Thread.Sleep(20);
            SetForegroundWindow(hWnd);
            Thread.Sleep(60);
        }
        return GetForegroundWindow() == hWnd;
    }

    public static bool PerformWindowAction(IntPtr hWnd, string action, int x, int y, int w, int h) {
        if (hWnd == IntPtr.Zero) return false;
        string act = (action ?? "focus").ToLowerInvariant();
        if (act == "focus") return FocusWindow(hWnd);
        if (act == "maximize") {
            FocusWindow(hWnd);
            return ShowWindow(hWnd, SW_MAXIMIZE);
        }
        if (act == "minimize") {
            return ShowWindow(hWnd, SW_MINIMIZE);
        }
        if (act == "restore") {
            ShowWindow(hWnd, SW_RESTORE);
            return FocusWindow(hWnd);
        }
        if (act == "move_resize") {
            FocusWindow(hWnd);
            return MoveWindow(hWnd, x, y, w, h, true);
        }
        if (act == "close") {
            SendMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            return true;
        }
        return false;
    }

    private static readonly HashSet<ControlType> InteractiveTypes = new HashSet<ControlType> {
        ControlType.Button,
        ControlType.Edit,
        ControlType.Document,
        ControlType.Hyperlink,
        ControlType.MenuItem,
        ControlType.TabItem,
        ControlType.ListItem,
        ControlType.TreeItem,
        ControlType.CheckBox,
        ControlType.RadioButton,
        ControlType.ComboBox,
        ControlType.Slider,
        ControlType.SplitButton,
        ControlType.DataItem
    };

    private static string ShortTypeName(ControlType ct) {
        if (ct == null) return "Control";
        string s = ct.ProgrammaticName ?? "Control";
        int idx = s.LastIndexOf('.');
        if (idx >= 0 && idx + 1 < s.Length) return s.Substring(idx + 1);
        return s;
    }

    private static void CollectElementsFromRoot(
        AutomationElement root,
        long windowHandle,
        int originX,
        int originY,
        int screenW,
        int screenH,
        int maxElements,
        int maxDepth,
        Stopwatch sw,
        int timeoutMs,
        List<UiElementInfo> results,
        ref bool truncated
    ) {
        if (root == null) return;
        int boundRight = originX + screenW;
        int boundBottom = originY + screenH;
        TreeWalker walker = TreeWalker.ControlViewWalker;
        Queue<KeyValuePair<AutomationElement, int>> queue = new Queue<KeyValuePair<AutomationElement, int>>();
        queue.Enqueue(new KeyValuePair<AutomationElement, int>(root, 0));

        while (queue.Count > 0) {
            if (sw.ElapsedMilliseconds > timeoutMs || results.Count >= maxElements) {
                truncated = true;
                break;
            }
            var pair = queue.Dequeue();
            AutomationElement el = pair.Key;
            int depth = pair.Value;

            try {
                if (depth > 0) {
                    bool isOffscreen = false;
                    try { isOffscreen = el.Current.IsOffscreen; } catch { }
                    if (isOffscreen) continue;

                    bool isEnabled = true;
                    try { isEnabled = el.Current.IsEnabled; } catch { }

                    Rect rect = Rect.Empty;
                    try { rect = el.Current.BoundingRectangle; } catch { }

                    if (!rect.IsEmpty && !double.IsInfinity(rect.Width) && !double.IsInfinity(rect.Height) &&
                        rect.Width >= 8 && rect.Height >= 8 &&
                        rect.Right > originX && rect.Bottom > originY &&
                        rect.Left < boundRight && rect.Top < boundBottom) {

                        ControlType ct = null;
                        try { ct = el.Current.ControlType; } catch { }

                        bool isInteractive = isEnabled && ct != null && InteractiveTypes.Contains(ct);
                        string name = "";
                        try { name = (el.Current.Name ?? "").Trim(); } catch { }

                        string val = "";
                        if (isInteractive && (ct == ControlType.Edit || ct == ControlType.ComboBox || ct == ControlType.Document)) {
                            try {
                                object vpObj;
                                if (el.TryGetCurrentPattern(ValuePattern.Pattern, out vpObj)) {
                                    ValuePattern vp = (ValuePattern)vpObj;
                                    val = (vp.Current.Value ?? "").Trim();
                                    if (val.Length > 80) val = val.Substring(0, 80) + "...";
                                }
                            } catch { }
                        }

                        if (isInteractive && (name.Length > 0 || val.Length > 0 || ct == ControlType.Edit || ct == ControlType.ComboBox || ct == ControlType.CheckBox || ct == ControlType.Slider)) {
                            int rx = Math.Max(originX, (int)Math.Round(rect.Left));
                            int ry = Math.Max(originY, (int)Math.Round(rect.Top));
                            int rr = Math.Min(boundRight, (int)Math.Round(rect.Right));
                            int rb = Math.Min(boundBottom, (int)Math.Round(rect.Bottom));
                            int rw = rr - rx;
                            int rh = rb - ry;

                            if (rw >= 8 && rh >= 8 && !(rw > screenW * 0.92 && rh > screenH * 0.92)) {
                                int cx = rx + rw / 2;
                                int cy = ry + rh / 2;

                                bool dup = false;
                                for (int k = results.Count - 1; k >= Math.Max(0, results.Count - 15); k--) {
                                    if (Math.Abs(results[k].Cx - cx) <= 6 && Math.Abs(results[k].Cy - cy) <= 6 && results[k].Name == name) {
                                        dup = true;
                                        break;
                                    }
                                }
                                if (!dup) {
                                    if (name.Length > 90) name = name.Substring(0, 90) + "...";
                                    UiElementInfo info = new UiElementInfo();
                                    info.Id = results.Count + 1;
                                    info.Type = ShortTypeName(ct);
                                    info.Name = name;
                                    info.Value = val;
                                    info.X = rx;
                                    info.Y = ry;
                                    info.Width = rw;
                                    info.Height = rh;
                                    info.Cx = cx;
                                    info.Cy = cy;
                                    info.WindowHandle = windowHandle;
                                    results.Add(info);
                                }
                            }
                        }
                    }
                }

                if (depth < maxDepth) {
                    AutomationElement child = null;
                    try { child = walker.GetFirstChild(el); } catch { }
                    int childCount = 0;
                    while (child != null && childCount < 150) {
                        if (sw.ElapsedMilliseconds > timeoutMs) {
                            truncated = true;
                            break;
                        }
                        queue.Enqueue(new KeyValuePair<AutomationElement, int>(child, depth + 1));
                        childCount++;
                        try { child = walker.GetNextSibling(child); } catch { child = null; }
                    }
                }
            } catch { }
        }
    }

    private static Color ColorForType(string type) {
        if (type == "Edit" || type == "Document" || type == "ComboBox") return Color.FromArgb(230, 16, 185, 129); // Emerald
        if (type == "Hyperlink" || type == "TabItem") return Color.FromArgb(230, 168, 85, 247); // Purple
        if (type == "MenuItem" || type == "ListItem" || type == "TreeItem") return Color.FromArgb(230, 245, 158, 11); // Amber
        return Color.FromArgb(230, 56, 189, 248); // Sky blue for buttons/default
    }

    public static System.Drawing.Rectangle GetTargetMonitorBounds(IntPtr hwnd, string monitorMode) {
        string mode = (monitorMode ?? "active").ToLowerInvariant();
        if (mode == "primary") {
            return Screen.PrimaryScreen.Bounds;
        }
        if (hwnd != IntPtr.Zero) {
            try {
                Screen s = Screen.FromHandle(hwnd);
                if (s != null) return s.Bounds;
            } catch { }
        }
        return Screen.PrimaryScreen.Bounds;
    }

    public static ScreenshotResult CaptureScreenshot(int originX, int originY, int screenW, int screenH, int maxWidth, List<UiElementInfo> annotations) {
        Bitmap bmp = new Bitmap(screenW, screenH);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.CopyFromScreen(originX, originY, 0, 0, new System.Drawing.Size(screenW, screenH));
        }

        int outW = screenW;
        int outH = screenH;
        double scaleX = 1.0;
        double scaleY = 1.0;
        Bitmap finalBmp = bmp;

        if (maxWidth > 0 && screenW > maxWidth) {
            double ratio = (double)maxWidth / (double)screenW;
            outW = maxWidth;
            outH = (int)Math.Round(screenH * ratio);
            scaleX = (double)outW / (double)screenW;
            scaleY = (double)outH / (double)screenH;
            Bitmap resized = new Bitmap(outW, outH);
            using (Graphics rg = Graphics.FromImage(resized)) {
                rg.InterpolationMode = InterpolationMode.HighQualityBicubic;
                rg.SmoothingMode = SmoothingMode.AntiAlias;
                rg.DrawImage(bmp, 0, 0, outW, outH);
            }
            bmp.Dispose();
            finalBmp = resized;
        }

        if (annotations != null && annotations.Count > 0) {
            using (Graphics ag = Graphics.FromImage(finalBmp)) {
                ag.SmoothingMode = SmoothingMode.AntiAlias;
                ag.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
                using (Font font = new Font("Segoe UI", 8.5f, System.Drawing.FontStyle.Bold))
                using (Brush textBrush = new SolidBrush(Color.White)) {
                    foreach (UiElementInfo el in annotations) {
                        float rx = (float)((el.X - originX) * scaleX);
                        float ry = (float)((el.Y - originY) * scaleY);
                        float rw = Math.Max(4f, (float)(el.Width * scaleX));
                        float rh = Math.Max(4f, (float)(el.Height * scaleY));

                        Color col = ColorForType(el.Type);
                        using (Pen pen = new Pen(col, 1.5f)) {
                            ag.DrawRectangle(pen, rx, ry, rw, rh);
                        }

                        string tag = el.Id.ToString();
                        SizeF sz = ag.MeasureString(tag, font);
                        float bx = rx;
                        float by = ry - sz.Height + 1;
                        if (by < 1) by = ry + 1;
                        if (bx + sz.Width + 4 > outW) bx = outW - sz.Width - 4;
                        if (bx < 1) bx = 1;

                        using (Brush bgBrush = new SolidBrush(Color.FromArgb(225, col.R / 2, col.G / 2, col.B / 2)))
                        using (Pen borderPen = new Pen(col, 1f)) {
                            ag.FillRectangle(bgBrush, bx, by, sz.Width + 3, sz.Height - 1);
                            ag.DrawRectangle(borderPen, bx, by, sz.Width + 3, sz.Height - 1);
                            ag.DrawString(tag, font, textBrush, bx + 1.5f, by - 0.5f);
                        }
                    }
                }
            }
        }

        string b64;
        using (MemoryStream ms = new MemoryStream()) {
            finalBmp.Save(ms, ImageFormat.Png);
            b64 = Convert.ToBase64String(ms.ToArray());
        }
        finalBmp.Dispose();

        ScreenshotResult res = new ScreenshotResult();
        res.OriginX = originX;
        res.OriginY = originY;
        res.ScreenWidth = screenW;
        res.ScreenHeight = screenH;
        res.ImageWidth = outW;
        res.ImageHeight = outH;
        res.PngBase64 = b64;
        return res;
    }

    public static ScreenshotResult CaptureZoomRegion(int centerX, int centerY, int width, int height, double zoomFactor, bool drawGrid) {
        if (width < 80) width = 80;
        if (width > 1200) width = 1200;
        if (height < 60) height = 60;
        if (height > 900) height = 900;
        if (zoomFactor < 1.0) zoomFactor = 1.0;
        if (zoomFactor > 4.0) zoomFactor = 4.0;

        System.Drawing.Rectangle vBounds = SystemInformation.VirtualScreen;
        int rx = centerX - width / 2;
        int ry = centerY - height / 2;
        if (rx < vBounds.Left) rx = vBounds.Left;
        if (ry < vBounds.Top) ry = vBounds.Top;
        if (rx + width > vBounds.Right) rx = Math.Max(vBounds.Left, vBounds.Right - width);
        if (ry + height > vBounds.Bottom) ry = Math.Max(vBounds.Top, vBounds.Bottom - height);
        int rw = Math.Min(width, vBounds.Right - rx);
        int rh = Math.Min(height, vBounds.Bottom - ry);

        Bitmap rawBmp = new Bitmap(rw, rh);
        using (Graphics g = Graphics.FromImage(rawBmp)) {
            g.CopyFromScreen(rx, ry, 0, 0, new System.Drawing.Size(rw, rh));
        }

        int outW = (int)Math.Round(rw * zoomFactor);
        int outH = (int)Math.Round(rh * zoomFactor);
        if (outW > 1280) {
            double r = 1280.0 / outW;
            outW = 1280;
            outH = (int)Math.Round(outH * r);
        }
        double scaleX = (double)outW / (double)rw;
        double scaleY = (double)outH / (double)rh;

        Bitmap zoomed = new Bitmap(outW, outH);
        using (Graphics zg = Graphics.FromImage(zoomed)) {
            zg.InterpolationMode = InterpolationMode.HighQualityBicubic;
            zg.SmoothingMode = SmoothingMode.AntiAlias;
            zg.DrawImage(rawBmp, 0, 0, outW, outH);

            if (drawGrid) {
                zg.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
                int step = (rw <= 320) ? 40 : 50;
                int firstX = (int)Math.Ceiling((double)rx / step) * step;
                int firstY = (int)Math.Ceiling((double)ry / step) * step;

                using (Pen gridPen = new Pen(Color.FromArgb(65, 217, 119, 87), 1f))
                using (Font font = new Font("Segoe UI", 8f, System.Drawing.FontStyle.Bold))
                using (Brush bg = new SolidBrush(Color.FromArgb(185, 24, 24, 27)))
                using (Brush fg = new SolidBrush(Color.FromArgb(245, 244, 244, 245))) {
                    for (int gx = firstX; gx < rx + rw; gx += step) {
                        float ix = (float)((gx - rx) * scaleX);
                        zg.DrawLine(gridPen, ix, 0, ix, outH);
                        string lbl = gx.ToString();
                        SizeF sz = zg.MeasureString(lbl, font);
                        zg.FillRectangle(bg, ix + 2, 2, sz.Width, sz.Height);
                        zg.DrawString(lbl, font, fg, ix + 2, 2);
                    }
                    for (int gy = firstY; gy < ry + rh; gy += step) {
                        float iy = (float)((gy - ry) * scaleY);
                        zg.DrawLine(gridPen, 0, iy, outW, iy);
                        string lbl = gy.ToString();
                        SizeF sz = zg.MeasureString(lbl, font);
                        zg.FillRectangle(bg, 2, iy + 2, sz.Width, sz.Height);
                        zg.DrawString(lbl, font, fg, 2, iy + 2);
                    }
                }
            }
        }
        rawBmp.Dispose();

        string b64;
        using (MemoryStream ms = new MemoryStream()) {
            zoomed.Save(ms, ImageFormat.Png);
            b64 = Convert.ToBase64String(ms.ToArray());
        }
        zoomed.Dispose();

        ScreenshotResult res = new ScreenshotResult();
        res.OriginX = rx;
        res.OriginY = ry;
        res.ScreenWidth = rw;
        res.ScreenHeight = rh;
        res.ImageWidth = outW;
        res.ImageHeight = outH;
        res.PngBase64 = b64;
        return res;
    }

    public static DesktopStateResult GetDesktopState(bool includeScreenshot, bool annotated, int maxWidth, int maxElements, bool includeTaskbar, string monitorMode) {
        IntPtr fgHwnd = GetForegroundWindow();
        System.Drawing.Rectangle mon = GetTargetMonitorBounds(fgHwnd, monitorMode);
        int originX = mon.X;
        int originY = mon.Y;
        int screenW = mon.Width;
        int screenH = mon.Height;

        List<WindowInfo> windows = ListWindows();
        WindowInfo active = null;
        foreach (var w in windows) {
            if (w.IsForeground) { active = w; break; }
        }

        List<UiElementInfo> elements = new List<UiElementInfo>();
        bool truncated = false;
        Stopwatch sw = Stopwatch.StartNew();

        if (fgHwnd != IntPtr.Zero) {
            try {
                AutomationElement fgEl = AutomationElement.FromHandle(fgHwnd);
                CollectElementsFromRoot(fgEl, fgHwnd.ToInt64(), originX, originY, screenW, screenH, maxElements, 14, sw, 1500, elements, ref truncated);
            } catch { }
        }

        if (includeTaskbar && elements.Count < maxElements && sw.ElapsedMilliseconds < 1800) {
            try {
                IntPtr trayHwnd = FindWindow("Shell_TrayWnd", null);
                if (trayHwnd != IntPtr.Zero && trayHwnd != fgHwnd) {
                    AutomationElement trayEl = AutomationElement.FromHandle(trayHwnd);
                    CollectElementsFromRoot(trayEl, 0, originX, originY, screenW, screenH, maxElements, 6, sw, 1900, elements, ref truncated);
                }
            } catch { }
        }

        LastElements.Clear();
        foreach (var el in elements) {
            LastElements[el.Id] = el;
        }

        ScreenshotResult shot = null;
        if (includeScreenshot) {
            shot = CaptureScreenshot(originX, originY, screenW, screenH, maxWidth, annotated ? elements : null);
        }

        POINT cur = GetCursor();
        DesktopStateResult res = new DesktopStateResult();
        res.OriginX = originX;
        res.OriginY = originY;
        res.ScreenWidth = screenW;
        res.ScreenHeight = screenH;
        res.ImageWidth = shot != null ? shot.ImageWidth : screenW;
        res.ImageHeight = shot != null ? shot.ImageHeight : screenH;
        res.CursorX = cur.X;
        res.CursorY = cur.Y;
        res.ActiveWindow = active;
        res.Windows = windows;
        res.Elements = elements;
        res.PngBase64 = shot != null ? shot.PngBase64 : null;
        res.Truncated = truncated;
        return res;
    }

    private static void GetButtonFlags(string button, out uint downFlag, out uint upFlag) {
        string b = (button == null) ? "left" : button.ToLowerInvariant();
        if (b == "right") {
            downFlag = MOUSEEVENTF_RIGHTDOWN;
            upFlag = MOUSEEVENTF_RIGHTUP;
        } else if (b == "middle") {
            downFlag = MOUSEEVENTF_MIDDLEDOWN;
            upFlag = MOUSEEVENTF_MIDDLEUP;
        } else {
            downFlag = MOUSEEVENTF_LEFTDOWN;
            upFlag = MOUSEEVENTF_LEFTUP;
        }
    }

    public static void SmoothMove(int targetX, int targetY, int durationMs) {
        if (durationMs <= 0) {
            SetCursorPos(targetX, targetY);
            return;
        }
        POINT start = GetCursor();
        int dx = targetX - start.X;
        int dy = targetY - start.Y;
        double dist = Math.Sqrt(dx * dx + dy * dy);
        if (dist < 4) {
            SetCursorPos(targetX, targetY);
            return;
        }
        int steps = Math.Max(6, Math.Min(18, durationMs / 8));
        int sleepMs = Math.Max(4, durationMs / steps);
        for (int i = 1; i <= steps; i++) {
            double t = (double)i / (double)steps;
            double ease = 1.0 - Math.Pow(1.0 - t, 3);
            int cx = (int)Math.Round(start.X + dx * ease);
            int cy = (int)Math.Round(start.Y + dy * ease);
            SetCursorPos(cx, cy);
            if (i < steps) Thread.Sleep(sleepMs);
        }
    }

    public static void MouseClick(int x, int y, bool hasPos, string button, int clicks, bool smooth) {
        if (hasPos) {
            if (smooth) SmoothMove(x, y, 100);
            else SetCursorPos(x, y);
            Thread.Sleep(20);
        }
        uint downFlag, upFlag;
        GetButtonFlags(button, out downFlag, out upFlag);
        if (clicks < 1) clicks = 1;
        for (int i = 0; i < clicks; i++) {
            mouse_event(downFlag, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(18);
            mouse_event(upFlag, 0, 0, 0, UIntPtr.Zero);
            if (i < clicks - 1) Thread.Sleep(45);
        }
    }

    public static void MouseDrag(int x1, int y1, int x2, int y2, string button, int steps, int durationMs) {
        if (steps < 2) steps = 2;
        if (durationMs < 0) durationMs = 0;
        uint downFlag, upFlag;
        GetButtonFlags(button, out downFlag, out upFlag);

        SmoothMove(x1, y1, 80);
        Thread.Sleep(15);
        mouse_event(downFlag, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(15);

        int delay = (steps > 0) ? (durationMs / steps) : 0;
        for (int i = 1; i <= steps; i++) {
            double t = (double)i / (double)steps;
            int cx = (int)Math.Round(x1 + (x2 - x1) * t);
            int cy = (int)Math.Round(y1 + (y2 - y1) * t);
            SetCursorPos(cx, cy);
            if (delay > 0) Thread.Sleep(delay);
        }

        Thread.Sleep(15);
        mouse_event(upFlag, 0, 0, 0, UIntPtr.Zero);
    }

    public static void MousePath(int[] xs, int[] ys, string button, bool holdButton, int stepDelayMs) {
        if (xs == null || ys == null || xs.Length == 0 || xs.Length != ys.Length) return;
        if (stepDelayMs < 0) stepDelayMs = 0;
        uint downFlag, upFlag;
        GetButtonFlags(button, out downFlag, out upFlag);

        SetCursorPos(xs[0], ys[0]);
        if (holdButton) {
            Thread.Sleep(10);
            mouse_event(downFlag, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(10);
        }

        for (int i = 1; i < xs.Length; i++) {
            SetCursorPos(xs[i], ys[i]);
            if (stepDelayMs > 0) Thread.Sleep(stepDelayMs);
        }

        if (holdButton) {
            Thread.Sleep(10);
            mouse_event(upFlag, 0, 0, 0, UIntPtr.Zero);
        }
    }

    public static void MouseScroll(int delta, int x, int y, bool hasPos) {
        if (hasPos) {
            SmoothMove(x, y, 70);
            Thread.Sleep(15);
        } else {
            // If cursor is outside the active foreground window (e.g. on another monitor), move it into the active window center
            IntPtr fg = GetForegroundWindow();
            RECT r;
            if (fg != IntPtr.Zero && GetWindowRect(fg, out r)) {
                POINT cur = GetCursor();
                if (cur.X < r.Left || cur.X > r.Right || cur.Y < r.Top || cur.Y > r.Bottom) {
                    int cx = (r.Left + r.Right) / 2;
                    int cy = (r.Top + r.Bottom) / 2;
                    SmoothMove(cx, cy, 60);
                    Thread.Sleep(15);
                }
            }
        }
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta * 120, UIntPtr.Zero);
    }

    private static bool IsExtendedKey(ushort vk) {
        return vk == 0x21 || vk == 0x22 || vk == 0x23 || vk == 0x24 ||
               vk == 0x25 || vk == 0x26 || vk == 0x27 || vk == 0x28 ||
               vk == 0x2D || vk == 0x2E || vk == 0x5B || vk == 0x5C;
    }

    public static INPUT MakeVkInput(ushort vk, bool keyUp) {
        uint flags = keyUp ? KEYEVENTF_KEYUP : 0;
        if (IsExtendedKey(vk)) flags |= KEYEVENTF_EXTENDEDKEY;
        ushort scan = (ushort)MapVirtualKey(vk, 0);
        INPUT inp = new INPUT();
        inp.type = INPUT_KEYBOARD;
        inp.U.ki.wVk = vk;
        inp.U.ki.wScan = scan;
        inp.U.ki.dwFlags = flags;
        inp.U.ki.time = 0;
        inp.U.ki.dwExtraInfo = UIntPtr.Zero;
        return inp;
    }

    public static void SendKeyCombo(ushort[] vks) {
        if (vks == null || vks.Length == 0) return;
        int sz = Marshal.SizeOf(typeof(INPUT));
        for (int i = 0; i < vks.Length; i++) {
            INPUT[] down = new INPUT[] { MakeVkInput(vks[i], false) };
            SendInput(1, down, sz);
            Thread.Sleep(14);
        }
        Thread.Sleep(16);
        for (int i = vks.Length - 1; i >= 0; i--) {
            INPUT[] up = new INPUT[] { MakeVkInput(vks[i], true) };
            SendInput(1, up, sz);
            Thread.Sleep(10);
        }
    }

    public static void TypeUnicode(string text) {
        List<INPUT> inputs = new List<INPUT>();
        foreach (char c in text) {
            if (c == '\r') continue;
            if (c == '\n') {
                inputs.Add(MakeVkInput(0x0D, false));
                inputs.Add(MakeVkInput(0x0D, true));
                continue;
            }
            INPUT down = new INPUT();
            down.type = INPUT_KEYBOARD;
            down.U.ki.wVk = 0;
            down.U.ki.wScan = (ushort)c;
            down.U.ki.dwFlags = KEYEVENTF_UNICODE;

            INPUT up = new INPUT();
            up.type = INPUT_KEYBOARD;
            up.U.ki.wVk = 0;
            up.U.ki.wScan = (ushort)c;
            up.U.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

            inputs.Add(down);
            inputs.Add(up);
        }
        if (inputs.Count > 0) {
            INPUT[] arr = inputs.ToArray();
            SendInput((uint)arr.Length, arr, Marshal.SizeOf(typeof(INPUT)));
        }
    }

    public static string GetClipboardText() {
        string result = "";
        Thread t = new Thread(() => {
            try {
                if (System.Windows.Forms.Clipboard.ContainsText()) {
                    result = System.Windows.Forms.Clipboard.GetText();
                }
            } catch { }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(1500);
        return result;
    }

    public static void SetClipboardText(string text) {
        Thread t = new Thread(() => {
            try {
                if (string.IsNullOrEmpty(text)) System.Windows.Forms.Clipboard.Clear();
                else System.Windows.Forms.Clipboard.SetText(text);
            } catch { }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(1500);
    }

    public static void PasteText(string text) {
        string prev = GetClipboardText();
        SetClipboardText(text);
        Thread.Sleep(30);
        SendKeyCombo(new ushort[] { 0x11, 0x56 }); // Ctrl+V
        Thread.Sleep(95);
        if (!string.IsNullOrEmpty(prev)) {
            SetClipboardText(prev);
        }
    }

    public static bool HasNonAscii(string s) {
        if (string.IsNullOrEmpty(s)) return false;
        foreach (char c in s) {
            if (c > 127 || c == '\n') return true;
        }
        return false;
    }

    public static int LaunchApp(string target, string args) {
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = target;
        if (!string.IsNullOrEmpty(args)) psi.Arguments = args;
        psi.UseShellExecute = true;
        Process p = Process.Start(psi);
        return p != null ? p.Id : 0;
    }
}
"@

Add-Type -TypeDefinition $csharp -Language CSharp -ReferencedAssemblies @(
    "System.Windows.Forms",
    "System.Drawing",
    "UIAutomationClient",
    "UIAutomationTypes",
    "WindowsBase"
)

[DesktopNative]::InitDpi()

$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$serializer.MaxJsonLength = [Int32]::MaxValue

$vkMap = @{
    "backspace" = 0x08; "bs" = 0x08; "back" = 0x08
    "tab" = 0x09
    "enter" = 0x0D; "return" = 0x0D
    "shift" = 0x10
    "ctrl" = 0x11; "control" = 0x11
    "alt" = 0x12; "menu" = 0x12
    "pause" = 0x13
    "capslock" = 0x14
    "esc" = 0x1B; "escape" = 0x1B
    "space" = 0x20
    "pageup" = 0x21; "pgup" = 0x21
    "pagedown" = 0x22; "pgdn" = 0x22
    "end" = 0x23
    "home" = 0x24
    "left" = 0x25; "up" = 0x26; "right" = 0x27; "down" = 0x28
    "printscreen" = 0x2C; "prtsc" = 0x2C
    "insert" = 0x2D; "ins" = 0x2D
    "delete" = 0x2E; "del" = 0x2E
    "win" = 0x5B; "lwin" = 0x5B; "meta" = 0x5B; "super" = 0x5B; "rwin" = 0x5C
    "f1" = 0x70; "f2" = 0x71; "f3" = 0x72; "f4" = 0x73; "f5" = 0x74; "f6" = 0x75
    "f7" = 0x76; "f8" = 0x77; "f9" = 0x78; "f10" = 0x79; "f11" = 0x7A; "f12" = 0x7B
    "plus" = 0xBB; "equal" = 0xBB; "equals" = 0xBB
    "minus" = 0xBD; "comma" = 0xBC; "period" = 0xBE; "dot" = 0xBE
    "slash" = 0xBF; "backslash" = 0xDC; "semicolon" = 0xBA; "quote" = 0xDE
    "lbracket" = 0xDB; "rbracket" = 0xDD; "grave" = 0xC0
}

function Resolve-KeyVks([string]$combo) {
    $parts = $combo.Split('+')
    $vks = New-Object System.Collections.Generic.List[uint16]
    foreach ($raw in $parts) {
        $k = $raw.Trim().ToLowerInvariant()
        if ($k.Length -eq 0) { continue }
        if ($vkMap.ContainsKey($k)) {
            $vks.Add([uint16]$vkMap[$k])
        } elseif ($k.Length -eq 1) {
            $ch = [int][char]$k.ToUpperInvariant()
            if (($ch -ge 48 -and $ch -le 57) -or ($ch -ge 65 -and $ch -le 90)) {
                $vks.Add([uint16]$ch)
            } else {
                throw "Unsupported key token: $raw"
            }
        } else {
            throw "Unknown key token: $raw"
        }
    }
    return $vks.ToArray()
}

function Find-WindowHandle($req) {
    if ($req.ContainsKey("handle") -and $null -ne $req["handle"]) {
        return [IntPtr]([long]$req["handle"])
    }
    $titleContains = if ($req.ContainsKey("titleContains") -and $req["titleContains"]) { [string]$req["titleContains"] } else { "" }
    $processName = if ($req.ContainsKey("processName") -and $req["processName"]) { [string]$req["processName"] } else { "" }
    $wins = [DesktopNative]::ListWindows()
    foreach ($w in $wins) {
        $matchTitle = ($titleContains -eq "") -or ($w.Title -like "*$titleContains*")
        $matchProc = ($processName -eq "") -or ($w.ProcessName -like "*$processName*")
        if ($matchTitle -and $matchProc) {
            return [IntPtr]$w.Handle
        }
    }
    return [IntPtr]::Zero
}

function Execute-Action($req) {
    $action = [string]$req["action"]
    switch ($action) {
        "desktop_state" {
            $includeScreenshot = if ($req.ContainsKey("includeScreenshot")) { [bool]$req["includeScreenshot"] } else { $true }
            $annotated = if ($req.ContainsKey("annotated")) { [bool]$req["annotated"] } else { $true }
            $maxWidth = if ($req.ContainsKey("maxWidth")) { [int]$req["maxWidth"] } else { 1280 }
            $maxElements = if ($req.ContainsKey("maxElements")) { [int]$req["maxElements"] } else { 80 }
            $includeTaskbar = if ($req.ContainsKey("includeTaskbar")) { [bool]$req["includeTaskbar"] } else { $true }
            $monitor = if ($req.ContainsKey("monitor") -and $req["monitor"]) { [string]$req["monitor"] } else { "active" }
            $st = [DesktopNative]::GetDesktopState($includeScreenshot, $annotated, $maxWidth, $maxElements, $includeTaskbar, $monitor)
            return @{
                originX = $st.OriginX
                originY = $st.OriginY
                screenWidth = $st.ScreenWidth
                screenHeight = $st.ScreenHeight
                imageWidth = $st.ImageWidth
                imageHeight = $st.ImageHeight
                cursorX = $st.CursorX
                cursorY = $st.CursorY
                activeWindow = $st.ActiveWindow
                windows = $st.Windows
                elements = $st.Elements
                truncated = $st.Truncated
                pngBase64 = $st.PngBase64
            }
        }
        "screenshot" {
            $maxWidth = if ($req.ContainsKey("maxWidth")) { [int]$req["maxWidth"] } else { 1280 }
            $monitor = if ($req.ContainsKey("monitor") -and $req["monitor"]) { [string]$req["monitor"] } else { "active" }
            $fg = [DesktopNative]::GetForegroundWindow()
            $mon = [DesktopNative]::GetTargetMonitorBounds($fg, $monitor)
            $shot = [DesktopNative]::CaptureScreenshot($mon.X, $mon.Y, $mon.Width, $mon.Height, $maxWidth, $null)
            return @{
                originX = $shot.OriginX
                originY = $shot.OriginY
                screenWidth = $shot.ScreenWidth
                screenHeight = $shot.ScreenHeight
                imageWidth = $shot.ImageWidth
                imageHeight = $shot.ImageHeight
                pngBase64 = $shot.PngBase64
            }
        }
        "zoom_region" {
            $cx = [int]$req["x"]
            $cy = [int]$req["y"]
            $w = if ($req.ContainsKey("width") -and $req["width"]) { [int]$req["width"] } else { 400 }
            $h = if ($req.ContainsKey("height") -and $req["height"]) { [int]$req["height"] } else { 300 }
            $z = if ($req.ContainsKey("zoom") -and $req["zoom"]) { [double]$req["zoom"] } else { 2.5 }
            $grid = if ($req.ContainsKey("drawGrid")) { [bool]$req["drawGrid"] } else { $true }
            $shot = [DesktopNative]::CaptureZoomRegion($cx, $cy, $w, $h, $z, $grid)
            return @{
                originX = $shot.OriginX
                originY = $shot.OriginY
                screenWidth = $shot.ScreenWidth
                screenHeight = $shot.ScreenHeight
                imageWidth = $shot.ImageWidth
                imageHeight = $shot.ImageHeight
                pngBase64 = $shot.PngBase64
            }
        }
        "click_element" {
            $elId = [int]$req["elementId"]
            if (-not [DesktopNative]::LastElements.ContainsKey($elId)) {
                throw "Element #$elId not found in cache. Call desktop_state first."
            }
            $el = [DesktopNative]::LastElements[$elId]
            $allowClose = if ($req.ContainsKey("allowClose")) { [bool]$req["allowClose"] } else { $false }
            $normName = if ($el.Name) { $el.Name.Trim().ToLowerInvariant() } else { "" }
            if (-not $allowClose -and ($normName -eq "close" -or $normName -eq "закрыть" -or $normName -eq "close window" -or $normName -eq "закрыть окно")) {
                throw "Blocked click on Close button (#$elId '$($el.Name)') to prevent accidentally closing an application. Pass allowClose: true only if the user explicitly asked to close it."
            }
            if ($el.WindowHandle -ne 0) {
                $curFg = [DesktopNative]::GetForegroundWindow()
                if ($curFg.ToInt64() -ne $el.WindowHandle) {
                    [DesktopNative]::FocusWindow([IntPtr]$el.WindowHandle) | Out-Null
                    [System.Threading.Thread]::Sleep(100)
                }
            }
            $button = if ($req.ContainsKey("button") -and $req["button"]) { [string]$req["button"] } else { "left" }
            $clicks = if ($req.ContainsKey("clicks") -and $req["clicks"]) { [int]$req["clicks"] } else { 1 }
            [DesktopNative]::MouseClick($el.Cx, $el.Cy, $true, $button, $clicks, $true)
            return @{
                ok = $true
                elementId = $elId
                name = $el.Name
                type = $el.Type
                x = $el.Cx
                y = $el.Cy
            }
        }
        "type_into_element" {
            $elId = [int]$req["elementId"]
            if (-not [DesktopNative]::LastElements.ContainsKey($elId)) {
                throw "Element #$elId not found in cache. Call desktop_state first."
            }
            $el = [DesktopNative]::LastElements[$elId]
            if ($el.WindowHandle -ne 0) {
                $curFg = [DesktopNative]::GetForegroundWindow()
                if ($curFg.ToInt64() -ne $el.WindowHandle) {
                    [DesktopNative]::FocusWindow([IntPtr]$el.WindowHandle) | Out-Null
                    [System.Threading.Thread]::Sleep(100)
                }
            }
            $text = [string]$req["text"]
            $clearFirst = if ($req.ContainsKey("clearFirst")) { [bool]$req["clearFirst"] } else { $false }
            $pressEnter = if ($req.ContainsKey("pressEnter")) { [bool]$req["pressEnter"] } else { $false }
            $useClipboard = if ($req.ContainsKey("useClipboard")) { [bool]$req["useClipboard"] } else { $true }

            [DesktopNative]::MouseClick($el.Cx, $el.Cy, $true, "left", 1, $true)
            [System.Threading.Thread]::Sleep(60)
            if ($clearFirst) {
                [DesktopNative]::SendKeyCombo([uint16[]]@(0x11, 0x41)) # Ctrl+A
                [System.Threading.Thread]::Sleep(30)
                [DesktopNative]::SendKeyCombo([uint16[]]@(0x08)) # Backspace
                [System.Threading.Thread]::Sleep(30)
            }
            if ($text.Length -gt 0) {
                if ($useClipboard) {
                    [DesktopNative]::PasteText($text)
                } else {
                    [DesktopNative]::TypeUnicode($text)
                }
            }
            if ($pressEnter) {
                [System.Threading.Thread]::Sleep(40)
                [DesktopNative]::SendKeyCombo([uint16[]]@(0x0D))
            }
            return @{
                ok = $true
                elementId = $elId
                name = $el.Name
                x = $el.Cx
                y = $el.Cy
                typedLength = $text.Length
            }
        }
        "mouse_click" {
            $hasPos = $req.ContainsKey("x") -and $req.ContainsKey("y") -and $null -ne $req["x"] -and $null -ne $req["y"]
            $x = if ($hasPos) { [int]$req["x"] } else { 0 }
            $y = if ($hasPos) { [int]$req["y"] } else { 0 }
            $button = if ($req.ContainsKey("button") -and $req["button"]) { [string]$req["button"] } else { "left" }
            $clicks = if ($req.ContainsKey("clicks") -and $req["clicks"]) { [int]$req["clicks"] } else { 1 }
            $smooth = if ($req.ContainsKey("smooth")) { [bool]$req["smooth"] } else { $true }
            [DesktopNative]::MouseClick($x, $y, $hasPos, $button, $clicks, $smooth)
            $cur = [DesktopNative]::GetCursor()
            return @{ ok = $true; x = $cur.X; y = $cur.Y }
        }
        "mouse_move" {
            $x = [int]$req["x"]
            $y = [int]$req["y"]
            $smooth = if ($req.ContainsKey("smooth")) { [bool]$req["smooth"] } else { $true }
            if ($smooth) { [DesktopNative]::SmoothMove($x, $y, 100) }
            else { [DesktopNative]::SetCursorPos($x, $y) | Out-Null }
            return @{ ok = $true; x = $x; y = $y }
        }
        "mouse_drag" {
            $x1 = [int]$req["x1"]; $y1 = [int]$req["y1"]
            $x2 = [int]$req["x2"]; $y2 = [int]$req["y2"]
            $button = if ($req.ContainsKey("button") -and $req["button"]) { [string]$req["button"] } else { "left" }
            $steps = if ($req.ContainsKey("steps") -and $req["steps"]) { [int]$req["steps"] } else { 20 }
            $dur = if ($req.ContainsKey("durationMs") -and $null -ne $req["durationMs"]) { [int]$req["durationMs"] } else { 180 }
            [DesktopNative]::MouseDrag($x1, $y1, $x2, $y2, $button, $steps, $dur)
            return @{ ok = $true; x1 = $x1; y1 = $y1; x2 = $x2; y2 = $y2 }
        }
        "mouse_path" {
            $pts = $req["points"]
            $xs = New-Object int[] $pts.Count
            $ys = New-Object int[] $pts.Count
            for ($i = 0; $i -lt $pts.Count; $i++) {
                $xs[$i] = [int]$pts[$i]["x"]
                $ys[$i] = [int]$pts[$i]["y"]
            }
            $button = if ($req.ContainsKey("button") -and $req["button"]) { [string]$req["button"] } else { "left" }
            $hold = if ($req.ContainsKey("holdButton")) { [bool]$req["holdButton"] } else { $true }
            $delay = if ($req.ContainsKey("stepDelayMs")) { [int]$req["stepDelayMs"] } else { 5 }
            [DesktopNative]::MousePath($xs, $ys, $button, $hold, $delay)
            return @{ ok = $true; pointsCount = $pts.Count }
        }
        "mouse_scroll" {
            $delta = [int]$req["delta"]
            $hasPos = $req.ContainsKey("x") -and $req.ContainsKey("y") -and $null -ne $req["x"] -and $null -ne $req["y"]
            $x = if ($hasPos) { [int]$req["x"] } else { 0 }
            $y = if ($hasPos) { [int]$req["y"] } else { 0 }
            [DesktopNative]::MouseScroll($delta, $x, $y, $hasPos)
            return @{ ok = $true; delta = $delta }
        }
        "type_text" {
            $text = [string]$req["text"]
            $useClipboard = if ($req.ContainsKey("useClipboard")) { [bool]$req["useClipboard"] } else { [DesktopNative]::HasNonAscii($text) -or ($text.Length -gt 24) }
            $pressEnter = if ($req.ContainsKey("pressEnter")) { [bool]$req["pressEnter"] } else { $false }
            if ($text.Length -gt 0) {
                if ($useClipboard) {
                    [DesktopNative]::PasteText($text)
                } else {
                    [DesktopNative]::TypeUnicode($text)
                }
            }
            if ($pressEnter) {
                [System.Threading.Thread]::Sleep(40)
                [DesktopNative]::SendKeyCombo([uint16[]]@(0x0D))
            }
            return @{ ok = $true; length = $text.Length; method = $(if ($useClipboard) { "clipboard" } else { "unicode" }) }
        }
        "key_press" {
            $combo = [string]$req["keys"]
            $vks = Resolve-KeyVks $combo
            [DesktopNative]::SendKeyCombo($vks)
            return @{ ok = $true; keys = $combo }
        }
        "list_windows" {
            $wins = [DesktopNative]::ListWindows()
            return @{ windows = $wins }
        }
        "focus_window" {
            $h = Find-WindowHandle $req
            if ($h -eq [IntPtr]::Zero) { throw "No matching window found" }
            $ok = [DesktopNative]::FocusWindow($h)
            return @{ ok = $ok; handle = $h.ToInt64() }
        }
        "window_action" {
            $h = Find-WindowHandle $req
            if ($h -eq [IntPtr]::Zero) { throw "No matching window found" }
            $wact = [string]$req["windowAction"]
            $x = if ($req.ContainsKey("x") -and $null -ne $req["x"]) { [int]$req["x"] } else { 0 }
            $y = if ($req.ContainsKey("y") -and $null -ne $req["y"]) { [int]$req["y"] } else { 0 }
            $w = if ($req.ContainsKey("width") -and $null -ne $req["width"]) { [int]$req["width"] } else { 1280 }
            $ht = if ($req.ContainsKey("height") -and $null -ne $req["height"]) { [int]$req["height"] } else { 800 }
            $ok = [DesktopNative]::PerformWindowAction($h, $wact, $x, $y, $w, $ht)
            return @{ ok = $ok; handle = $h.ToInt64(); windowAction = $wact }
        }
        "launch_app" {
            $target = [string]$req["target"]
            $args = if ($req.ContainsKey("args") -and $req["args"]) { [string]$req["args"] } else { "" }
            $pidOut = [DesktopNative]::LaunchApp($target, $args)
            return @{ ok = $true; target = $target; pid = $pidOut }
        }
        "clipboard" {
            $mode = if ($req.ContainsKey("mode") -and $req["mode"]) { ([string]$req["mode"]).ToLowerInvariant() } else { "get" }
            if ($mode -eq "set") {
                [DesktopNative]::SetClipboardText([string]$req["text"])
                return @{ ok = $true; mode = "set" }
            } else {
                $txt = [DesktopNative]::GetClipboardText()
                return @{ ok = $true; mode = "get"; text = $txt }
            }
        }
        "sleep" {
            $ms = [int]$req["ms"]
            if ($ms -gt 0) { [System.Threading.Thread]::Sleep($ms) }
            return @{ ok = $true; ms = $ms }
        }
        "batch" {
            $items = $req["actions"]
            $results = New-Object System.Collections.Generic.List[object]
            foreach ($it in $items) {
                $r = Execute-Action $it
                $results.Add($r)
            }
            return @{ ok = $true; count = $results.Count; results = $results.ToArray() }
        }
        default {
            throw "Unknown action: $action"
        }
    }
}

[Console]::Out.WriteLine('{"ready":true}')
[Console]::Out.Flush()

while ($true) {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) { break }
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0) { continue }

    $id = $null
    try {
        $req = $serializer.DeserializeObject($trimmed)
        $id = $req["id"]
        $res = Execute-Action $req
        $outObj = @{ id = $id; ok = $true; result = $res }
        [Console]::Out.WriteLine($serializer.Serialize($outObj))
        [Console]::Out.Flush()
    } catch {
        $errMsg = $_.Exception.Message
        $outObj = @{ id = $id; ok = $false; error = $errMsg }
        [Console]::Out.WriteLine($serializer.Serialize($outObj))
        [Console]::Out.Flush()
    }
}
