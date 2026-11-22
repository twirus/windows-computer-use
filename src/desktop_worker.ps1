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
    public const uint MOUSEEVENTF_HWHEEL = 0x01000;

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
        public string State;
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
        public string MimeType;
        public string ImageBase64;
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
        public string MimeType;
        public string ImageBase64;
        public bool Truncated;
    }

    public class WaitForResult {
        public bool Matched;
        public long ElapsedMs;
        public WindowInfo Window;
        public UiElementInfo Element;
        public bool ScreenChanged;
    }

    public static Dictionary<int, UiElementInfo> LastElements = new Dictionary<int, UiElementInfo>();
    private static int _heavyCallCount = 0;

    private static void MaybeCollectGarbage() {
        _heavyCallCount++;
        if (_heavyCallCount >= 12) {
            _heavyCallCount = 0;
            try {
                GC.Collect();
                GC.WaitForPendingFinalizers();
            } catch { }
        }
    }

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
                using (Process p = Process.GetProcessById((int)pid)) {
                    procName = p.ProcessName;
                }
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

    private static CacheRequest CreateUiCacheRequest() {
        CacheRequest cr = new CacheRequest();
        cr.TreeScope = TreeScope.Element;
        cr.AutomationElementMode = AutomationElementMode.Full;
        cr.Add(AutomationElement.NameProperty);
        cr.Add(AutomationElement.ControlTypeProperty);
        cr.Add(AutomationElement.BoundingRectangleProperty);
        cr.Add(AutomationElement.IsOffscreenProperty);
        cr.Add(AutomationElement.IsEnabledProperty);
        cr.Add(AutomationElement.HasKeyboardFocusProperty);
        cr.Add(ValuePattern.Pattern);
        cr.Add(ValuePattern.ValueProperty);
        cr.Add(TogglePattern.Pattern);
        cr.Add(TogglePattern.ToggleStateProperty);
        cr.Add(SelectionItemPattern.Pattern);
        cr.Add(SelectionItemPattern.IsSelectedProperty);
        cr.Add(ExpandCollapsePattern.Pattern);
        cr.Add(ExpandCollapsePattern.ExpandCollapseStateProperty);
        return cr;
    }

    private static string ExtractCachedState(AutomationElement el, ControlType ct, bool hasFocus) {
        List<string> flags = new List<string>();
        try {
            object patObj;
            if (ct == ControlType.CheckBox || ct == ControlType.RadioButton || ct == ControlType.Button) {
                if (el.TryGetCachedPattern(TogglePattern.Pattern, out patObj)) {
                    ToggleState ts = ((TogglePattern)patObj).Cached.ToggleState;
                    if (ts == ToggleState.On) flags.Add("checked");
                    else if (ts == ToggleState.Off) flags.Add("unchecked");
                    else if (ts == ToggleState.Indeterminate) flags.Add("indeterminate");
                }
            }
            if (ct == ControlType.TabItem || ct == ControlType.ListItem || ct == ControlType.TreeItem || ct == ControlType.RadioButton || ct == ControlType.DataItem) {
                if (el.TryGetCachedPattern(SelectionItemPattern.Pattern, out patObj)) {
                    if (((SelectionItemPattern)patObj).Cached.IsSelected) flags.Add("selected");
                }
            }
            if (ct == ControlType.TreeItem || ct == ControlType.ComboBox || ct == ControlType.MenuItem || ct == ControlType.SplitButton) {
                if (el.TryGetCachedPattern(ExpandCollapsePattern.Pattern, out patObj)) {
                    ExpandCollapseState ecs = ((ExpandCollapsePattern)patObj).Cached.ExpandCollapseState;
                    if (ecs == ExpandCollapseState.Expanded) flags.Add("expanded");
                    else if (ecs == ExpandCollapseState.Collapsed) flags.Add("collapsed");
                }
            }
        } catch { }
        if (hasFocus) flags.Add("focused");
        return flags.Count > 0 ? string.Join(",", flags) : "";
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
        ref bool truncated,
        string filterQuery = "",
        string filterType = ""
    ) {
        if (root == null) return;
        string qNeedle = (filterQuery ?? "").Trim();
        string tNeedle = (filterType ?? "").Trim();
        int boundRight = originX + screenW;
        int boundBottom = originY + screenH;
        TreeWalker walker = TreeWalker.ControlViewWalker;
        CacheRequest cacheReq = CreateUiCacheRequest();
        Queue<KeyValuePair<AutomationElement, int>> queue = new Queue<KeyValuePair<AutomationElement, int>>();
        queue.Enqueue(new KeyValuePair<AutomationElement, int>(root, 0));

        using (cacheReq.Activate()) {
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
                        try { isOffscreen = el.Cached.IsOffscreen; } catch { }
                        if (isOffscreen) continue;

                        bool isEnabled = true;
                        try { isEnabled = el.Cached.IsEnabled; } catch { }

                        Rect rect = Rect.Empty;
                        try { rect = el.Cached.BoundingRectangle; } catch { }

                        if (!rect.IsEmpty && !double.IsInfinity(rect.Width) && !double.IsInfinity(rect.Height) &&
                            rect.Width >= 8 && rect.Height >= 8 &&
                            rect.Right > originX && rect.Bottom > originY &&
                            rect.Left < boundRight && rect.Top < boundBottom) {

                            ControlType ct = null;
                            try { ct = el.Cached.ControlType; } catch { }

                            bool isInteractive = isEnabled && ct != null && InteractiveTypes.Contains(ct);
                            string name = "";
                            try { name = (el.Cached.Name ?? "").Trim(); } catch { }

                            string val = "";
                            if (isInteractive && (ct == ControlType.Edit || ct == ControlType.ComboBox || ct == ControlType.Document)) {
                                try {
                                    object vpObj;
                                    if (el.TryGetCachedPattern(ValuePattern.Pattern, out vpObj)) {
                                        ValuePattern vp = (ValuePattern)vpObj;
                                        val = (vp.Cached.Value ?? "").Trim();
                                        if (val.Length > 80) val = val.Substring(0, 80) + "...";
                                    }
                                } catch { }
                            }

                            if (isInteractive && (name.Length > 0 || val.Length > 0 || ct == ControlType.Edit || ct == ControlType.ComboBox || ct == ControlType.CheckBox || ct == ControlType.Slider)) {
                                string shortType = ShortTypeName(ct);
                                bool matchesQuery = qNeedle.Length == 0 ||
                                    name.IndexOf(qNeedle, StringComparison.OrdinalIgnoreCase) >= 0 ||
                                    val.IndexOf(qNeedle, StringComparison.OrdinalIgnoreCase) >= 0;
                                bool matchesType = tNeedle.Length == 0 ||
                                    shortType.IndexOf(tNeedle, StringComparison.OrdinalIgnoreCase) >= 0;

                                if (matchesQuery && matchesType) {
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
                                            bool hasFocus = false;
                                            try { hasFocus = el.Cached.HasKeyboardFocus; } catch { }
                                            string state = ExtractCachedState(el, ct, hasFocus);

                                            if (name.Length > 90) name = name.Substring(0, 90) + "...";
                                            UiElementInfo info = new UiElementInfo();
                                            info.Id = results.Count + 1;
                                            info.Type = shortType;
                                            info.Name = name;
                                            info.Value = val;
                                            info.State = state;
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
                    }

                    if (depth < maxDepth) {
                        AutomationElement child = null;
                        try { child = walker.GetFirstChild(el, cacheReq); } catch { }
                        int childCount = 0;
                        while (child != null && childCount < 150) {
                            if (sw.ElapsedMilliseconds > timeoutMs) {
                                truncated = true;
                                break;
                            }
                            queue.Enqueue(new KeyValuePair<AutomationElement, int>(child, depth + 1));
                            childCount++;
                            try { child = walker.GetNextSibling(child, cacheReq); } catch { child = null; }
                        }
                    }
                } catch { }
            }
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

    public static System.Drawing.Rectangle GetTargetCaptureBounds(IntPtr hwnd, string monitorMode, string scope) {
        string sc = (scope ?? "monitor").ToLowerInvariant();
        if (sc == "window" && hwnd != IntPtr.Zero && !IsIconic(hwnd)) {
            RECT r;
            if (GetWindowRect(hwnd, out r)) {
                System.Drawing.Rectangle vBounds = SystemInformation.VirtualScreen;
                int left = Math.Max(vBounds.Left, r.Left);
                int top = Math.Max(vBounds.Top, r.Top);
                int right = Math.Min(vBounds.Right, r.Right);
                int bottom = Math.Min(vBounds.Bottom, r.Bottom);
                int w = right - left;
                int h = bottom - top;
                if (w >= 60 && h >= 60) {
                    return new System.Drawing.Rectangle(left, top, w, h);
                }
            }
        }
        return GetTargetMonitorBounds(hwnd, monitorMode);
    }

    private static ImageCodecInfo _jpegCodec = null;
    private static ImageCodecInfo GetJpegCodec() {
        if (_jpegCodec != null) return _jpegCodec;
        foreach (ImageCodecInfo codec in ImageCodecInfo.GetImageEncoders()) {
            if (codec.MimeType == "image/jpeg") {
                _jpegCodec = codec;
                return codec;
            }
        }
        return null;
    }

    private static string EncodeBitmap(Bitmap bmp, string format, int quality, out string mimeType) {
        string fmt = (format ?? "jpeg").ToLowerInvariant();
        if (quality < 40) quality = 40;
        if (quality > 100) quality = 100;
        using (MemoryStream ms = new MemoryStream()) {
            ImageCodecInfo jpegCodec = (fmt == "jpeg" || fmt == "jpg") ? GetJpegCodec() : null;
            if (jpegCodec != null) {
                using (EncoderParameters ep = new EncoderParameters(1)) {
                    ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, (long)quality);
                    bmp.Save(ms, jpegCodec, ep);
                }
                mimeType = "image/jpeg";
            } else {
                bmp.Save(ms, ImageFormat.Png);
                mimeType = "image/png";
            }
            return Convert.ToBase64String(ms.ToArray());
        }
    }

    private static bool RectOverlapsAny(RectangleF candidate, List<RectangleF> placed) {
        for (int i = 0; i < placed.Count; i++) {
            if (candidate.IntersectsWith(placed[i])) return true;
        }
        return false;
    }

    public static ScreenshotResult CaptureScreenshot(int originX, int originY, int screenW, int screenH, int maxWidth, List<UiElementInfo> annotations, string format, int quality, bool allowGc) {
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
            if (maxWidth < 160) maxWidth = 160;
            double ratio = (double)maxWidth / (double)screenW;
            outW = maxWidth;
            outH = Math.Max(1, (int)Math.Round(screenH * ratio));
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
            List<RectangleF> placedBadges = new List<RectangleF>(annotations.Count);
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
                        float bw = sz.Width + 3f;
                        float bh = sz.Height - 1f;
                        float bx = rx;
                        float by = ry - bh;
                        if (by < 1f) by = ry + 1f;
                        if (bx + bw + 1f > outW) bx = outW - bw - 1f;
                        if (bx < 1f) bx = 1f;

                        // Anti-overlap: try alternate positions around the element if badge collides
                        RectangleF badgeRect = new RectangleF(bx, by, bw, bh);
                        if (RectOverlapsAny(badgeRect, placedBadges)) {
                            float[] candX = new float[] {
                                rx + rw - bw,
                                rx,
                                rx + bw + 2f,
                                rx + rw + 2f
                            };
                            float[] candY = new float[] {
                                ry - bh,
                                ry + rh + 1f,
                                ry + 1f,
                                ry + rh - bh
                            };
                            bool foundFree = false;
                            for (int ci = 0; ci < candX.Length && !foundFree; ci++) {
                                float tx = Math.Max(1f, Math.Min(outW - bw - 1f, candX[ci]));
                                float ty = Math.Max(1f, Math.Min(outH - bh - 1f, candY[ci]));
                                RectangleF cand = new RectangleF(tx, ty, bw, bh);
                                if (!RectOverlapsAny(cand, placedBadges)) {
                                    bx = tx;
                                    by = ty;
                                    badgeRect = cand;
                                    foundFree = true;
                                }
                            }
                        }
                        placedBadges.Add(badgeRect);

                        using (Brush bgBrush = new SolidBrush(Color.FromArgb(225, col.R / 2, col.G / 2, col.B / 2)))
                        using (Pen borderPen = new Pen(col, 1f)) {
                            ag.FillRectangle(bgBrush, bx, by, bw, bh);
                            ag.DrawRectangle(borderPen, bx, by, bw, bh);
                            ag.DrawString(tag, font, textBrush, bx + 1.5f, by - 0.5f);
                        }
                    }
                }
            }
        }

        string mime;
        string b64 = EncodeBitmap(finalBmp, format, quality, out mime);
        finalBmp.Dispose();

        ScreenshotResult res = new ScreenshotResult();
        res.OriginX = originX;
        res.OriginY = originY;
        res.ScreenWidth = screenW;
        res.ScreenHeight = screenH;
        res.ImageWidth = outW;
        res.ImageHeight = outH;
        res.MimeType = mime;
        res.ImageBase64 = b64;
        if (allowGc) MaybeCollectGarbage();
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
        res.MimeType = "image/png";
        res.ImageBase64 = b64;
        MaybeCollectGarbage();
        return res;
    }

    public static DesktopStateResult GetDesktopState(bool includeScreenshot, bool annotated, int maxWidth, int maxElements, bool includeTaskbar, string monitorMode, string scope, string format, int quality, string filter) {
        IntPtr fgHwnd = GetForegroundWindow();
        System.Drawing.Rectangle bounds = GetTargetCaptureBounds(fgHwnd, monitorMode, scope);
        int originX = bounds.X;
        int originY = bounds.Y;
        int screenW = bounds.Width;
        int screenH = bounds.Height;

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
                CollectElementsFromRoot(fgEl, fgHwnd.ToInt64(), originX, originY, screenW, screenH, maxElements, 14, sw, 1500, elements, ref truncated, filter, "");
            } catch { }
        }

        bool isWindowScope = ((scope ?? "monitor").ToLowerInvariant() == "window");
        if (includeTaskbar && !isWindowScope && elements.Count < maxElements && sw.ElapsedMilliseconds < 1800) {
            try {
                IntPtr trayHwnd = FindWindow("Shell_TrayWnd", null);
                if (trayHwnd != IntPtr.Zero && trayHwnd != fgHwnd) {
                    AutomationElement trayEl = AutomationElement.FromHandle(trayHwnd);
                    CollectElementsFromRoot(trayEl, 0, originX, originY, screenW, screenH, maxElements, 6, sw, 1900, elements, ref truncated, filter, "");
                }
            } catch { }
        }

        LastElements.Clear();
        foreach (var el in elements) {
            LastElements[el.Id] = el;
        }

        ScreenshotResult shot = null;
        if (includeScreenshot) {
            shot = CaptureScreenshot(originX, originY, screenW, screenH, maxWidth, annotated ? elements : null, format, quality, false);
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
        res.MimeType = shot != null ? shot.MimeType : null;
        res.ImageBase64 = shot != null ? shot.ImageBase64 : null;
        res.Truncated = truncated;
        MaybeCollectGarbage();
        return res;
    }

    public static List<UiElementInfo> FindElements(string query, string controlType, int maxResults, bool includeTaskbar) {
        if (maxResults < 1) maxResults = 1;
        if (maxResults > 100) maxResults = 100;
        IntPtr fgHwnd = GetForegroundWindow();
        System.Drawing.Rectangle mon = GetTargetMonitorBounds(fgHwnd, "active");
        List<UiElementInfo> elements = new List<UiElementInfo>();
        bool truncated = false;
        Stopwatch sw = Stopwatch.StartNew();

        if (fgHwnd != IntPtr.Zero) {
            try {
                AutomationElement fgEl = AutomationElement.FromHandle(fgHwnd);
                CollectElementsFromRoot(fgEl, fgHwnd.ToInt64(), mon.X, mon.Y, mon.Width, mon.Height, maxResults, 18, sw, 2200, elements, ref truncated, query, controlType);
            } catch { }
        }

        if (includeTaskbar && elements.Count < maxResults && sw.ElapsedMilliseconds < 2500) {
            try {
                IntPtr trayHwnd = FindWindow("Shell_TrayWnd", null);
                if (trayHwnd != IntPtr.Zero && trayHwnd != fgHwnd) {
                    AutomationElement trayEl = AutomationElement.FromHandle(trayHwnd);
                    CollectElementsFromRoot(trayEl, 0, mon.X, mon.Y, mon.Width, mon.Height, maxResults, 6, sw, 2600, elements, ref truncated, query, controlType);
                }
            } catch { }
        }

        if (elements.Count > 0) {
            int nextId = 1;
            foreach (int existingId in LastElements.Keys) {
                if (existingId >= nextId) nextId = existingId + 1;
            }
            foreach (var el in elements) {
                el.Id = nextId++;
                LastElements[el.Id] = el;
            }
        }
        MaybeCollectGarbage();
        return elements;
    }

    public static bool TrySetElementValueDirect(int cx, int cy, string text) {
        try {
            AutomationElement el = AutomationElement.FromPoint(new System.Windows.Point(cx, cy));
            if (el == null) return false;
            object vpObj;
            if (el.TryGetCurrentPattern(ValuePattern.Pattern, out vpObj)) {
                ValuePattern vp = (ValuePattern)vpObj;
                if (!vp.Current.IsReadOnly) {
                    vp.SetValue(text ?? "");
                    return true;
                }
            }
        } catch { }
        return false;
    }

    private static byte[] CaptureScreenFingerprint(System.Drawing.Rectangle bounds) {
        try {
            if (bounds.Width <= 0 || bounds.Height <= 0) return null;
            using (Bitmap full = new Bitmap(bounds.Width, bounds.Height)) {
                using (Graphics g = Graphics.FromImage(full)) {
                    g.CopyFromScreen(bounds.X, bounds.Y, 0, 0, new System.Drawing.Size(bounds.Width, bounds.Height));
                }
                const int fw = 32;
                const int fh = 18;
                using (Bitmap small = new Bitmap(fw, fh)) {
                    using (Graphics sg = Graphics.FromImage(small)) {
                        sg.InterpolationMode = InterpolationMode.Bilinear;
                        sg.DrawImage(full, 0, 0, fw, fh);
                    }
                    byte[] data = new byte[fw * fh];
                    int idx = 0;
                    for (int y = 0; y < fh; y++) {
                        for (int x = 0; x < fw; x++) {
                            Color c = small.GetPixel(x, y);
                            data[idx++] = (byte)((c.R * 30 + c.G * 59 + c.B * 11) / 100);
                        }
                    }
                    return data;
                }
            }
        } catch {
            return null;
        }
    }

    private static double FingerprintDiffRatio(byte[] a, byte[] b) {
        if (a == null || b == null || a.Length != b.Length || a.Length == 0) return 0.0;
        int changed = 0;
        for (int i = 0; i < a.Length; i++) {
            if (Math.Abs((int)a[i] - (int)b[i]) >= 12) changed++;
        }
        return (double)changed / (double)a.Length;
    }

    public static WaitForResult WaitForCondition(string windowTitleContains, string processName, string elementNameContains, bool screenChange, int timeoutMs, int pollMs) {
        if (timeoutMs < 200) timeoutMs = 200;
        if (timeoutMs > 15000) timeoutMs = 15000;
        if (pollMs < 100) pollMs = 100;
        if (pollMs > 1000) pollMs = 1000;

        string titleNeedle = (windowTitleContains ?? "").Trim();
        string procNeedle = (processName ?? "").Trim();
        string elNeedle = (elementNameContains ?? "").Trim();

        System.Drawing.Rectangle watchBounds = System.Drawing.Rectangle.Empty;
        byte[] baselineFp = null;
        if (screenChange) {
            IntPtr fgInit = GetForegroundWindow();
            watchBounds = GetTargetMonitorBounds(fgInit, "active");
            baselineFp = CaptureScreenFingerprint(watchBounds);
        }

        Stopwatch sw = Stopwatch.StartNew();
        WaitForResult res = new WaitForResult();
        res.Matched = false;

        while (true) {
            if (titleNeedle.Length > 0 || procNeedle.Length > 0) {
                List<WindowInfo> wins = ListWindows();
                foreach (var w in wins) {
                    bool okTitle = titleNeedle.Length == 0 || (w.Title != null && w.Title.IndexOf(titleNeedle, StringComparison.OrdinalIgnoreCase) >= 0);
                    bool okProc = procNeedle.Length == 0 || (w.ProcessName != null && w.ProcessName.IndexOf(procNeedle, StringComparison.OrdinalIgnoreCase) >= 0);
                    if (okTitle && okProc) {
                        res.Window = w;
                        if (elNeedle.Length == 0 && !screenChange) {
                            res.Matched = true;
                            res.ElapsedMs = sw.ElapsedMilliseconds;
                            return res;
                        }
                        break;
                    }
                }
            }

            if (elNeedle.Length > 0) {
                IntPtr fgHwnd = GetForegroundWindow();
                if (fgHwnd != IntPtr.Zero) {
                    try {
                        System.Drawing.Rectangle mon = GetTargetMonitorBounds(fgHwnd, "active");
                        List<UiElementInfo> found = new List<UiElementInfo>();
                        bool trunc = false;
                        Stopwatch scanSw = Stopwatch.StartNew();
                        AutomationElement fgEl = AutomationElement.FromHandle(fgHwnd);
                        CollectElementsFromRoot(fgEl, fgHwnd.ToInt64(), mon.X, mon.Y, mon.Width, mon.Height, 10, 14, scanSw, 600, found, ref trunc, elNeedle, "");
                        if (found.Count > 0) {
                            res.Matched = true;
                            res.Element = found[0];
                            res.ElapsedMs = sw.ElapsedMilliseconds;
                            return res;
                        }
                    } catch { }
                }
            }

            if (screenChange && baselineFp != null && sw.ElapsedMilliseconds >= pollMs) {
                byte[] curFp = CaptureScreenFingerprint(watchBounds);
                if (FingerprintDiffRatio(baselineFp, curFp) >= 0.015) {
                    res.Matched = true;
                    res.ScreenChanged = true;
                    res.ElapsedMs = sw.ElapsedMilliseconds;
                    return res;
                }
            }

            if (sw.ElapsedMilliseconds >= timeoutMs) {
                res.ElapsedMs = sw.ElapsedMilliseconds;
                return res;
            }
            int remaining = (int)(timeoutMs - sw.ElapsedMilliseconds);
            Thread.Sleep(Math.Min(pollMs, Math.Max(20, remaining)));
        }
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

    public static void MouseClick(int x, int y, bool hasPos, string button, int clicks, bool smooth, ushort[] modifierVks) {
        if (hasPos) {
            if (smooth) SmoothMove(x, y, 100);
            else SetCursorPos(x, y);
            Thread.Sleep(20);
        }
        uint downFlag, upFlag;
        GetButtonFlags(button, out downFlag, out upFlag);
        if (clicks < 1) clicks = 1;
        int sz = Marshal.SizeOf(typeof(INPUT));
        bool hasMods = modifierVks != null && modifierVks.Length > 0;
        if (hasMods) {
            for (int m = 0; m < modifierVks.Length; m++) {
                INPUT[] down = new INPUT[] { MakeVkInput(modifierVks[m], false) };
                SendInput(1, down, sz);
                Thread.Sleep(14);
            }
        }
        try {
            for (int i = 0; i < clicks; i++) {
                mouse_event(downFlag, 0, 0, 0, UIntPtr.Zero);
                Thread.Sleep(18);
                mouse_event(upFlag, 0, 0, 0, UIntPtr.Zero);
                if (i < clicks - 1) Thread.Sleep(45);
            }
        } finally {
            if (hasMods) {
                Thread.Sleep(14);
                for (int m = modifierVks.Length - 1; m >= 0; m--) {
                    INPUT[] up = new INPUT[] { MakeVkInput(modifierVks[m], true) };
                    SendInput(1, up, sz);
                    Thread.Sleep(10);
                }
            }
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

    public static void MouseScroll(int delta, int horizontalDelta, int x, int y, bool hasPos) {
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
        if (delta != 0) {
            mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta * 120, UIntPtr.Zero);
        }
        if (horizontalDelta != 0) {
            mouse_event(MOUSEEVENTF_HWHEEL, 0, 0, horizontalDelta * 120, UIntPtr.Zero);
        }
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
            for (int attempt = 0; attempt < 3; attempt++) {
                try {
                    if (System.Windows.Forms.Clipboard.ContainsText()) {
                        result = System.Windows.Forms.Clipboard.GetText();
                    }
                    return;
                } catch {
                    Thread.Sleep(25);
                }
            }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(1500);
        return result;
    }

    public static void SetClipboardText(string text) {
        Thread t = new Thread(() => {
            for (int attempt = 0; attempt < 3; attempt++) {
                try {
                    if (string.IsNullOrEmpty(text)) System.Windows.Forms.Clipboard.Clear();
                    else System.Windows.Forms.Clipboard.SetText(text);
                    return;
                } catch {
                    Thread.Sleep(25);
                }
            }
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
        using (Process p = Process.Start(psi)) {
            return p != null ? p.Id : 0;
        }
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
    if ($titleContains -eq "" -and $processName -eq "") {
        throw "Specify handle, titleContains, or processName to target a window."
    }
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

function Resolve-ModifierVks($mods) {
    if ($null -eq $mods) { return $null }
    $vks = New-Object System.Collections.Generic.List[uint16]
    foreach ($m in $mods) {
        $k = ([string]$m).Trim().ToLowerInvariant()
        if ($k -eq "ctrl" -or $k -eq "control") { $vks.Add([uint16]0x11) }
        elseif ($k -eq "shift") { $vks.Add([uint16]0x10) }
        elseif ($k -eq "alt" -or $k -eq "menu") { $vks.Add([uint16]0x12) }
    }
    if ($vks.Count -eq 0) { return $null }
    return $vks.ToArray()
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
            $scope = if ($req.ContainsKey("scope") -and $req["scope"]) { [string]$req["scope"] } else { "monitor" }
            $format = if ($req.ContainsKey("format") -and $req["format"]) { [string]$req["format"] } else { "jpeg" }
            $quality = if ($req.ContainsKey("quality") -and $null -ne $req["quality"]) { [int]$req["quality"] } else { 82 }
            $filter = if ($req.ContainsKey("filter") -and $req["filter"]) { [string]$req["filter"] } else { "" }
            $st = [DesktopNative]::GetDesktopState($includeScreenshot, $annotated, $maxWidth, $maxElements, $includeTaskbar, $monitor, $scope, $format, $quality, $filter)
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
                mimeType = $st.MimeType
                imageBase64 = $st.ImageBase64
            }
        }
        "screenshot" {
            $maxWidth = if ($req.ContainsKey("maxWidth")) { [int]$req["maxWidth"] } else { 1280 }
            $monitor = if ($req.ContainsKey("monitor") -and $req["monitor"]) { [string]$req["monitor"] } else { "active" }
            $scope = if ($req.ContainsKey("scope") -and $req["scope"]) { [string]$req["scope"] } else { "monitor" }
            $format = if ($req.ContainsKey("format") -and $req["format"]) { [string]$req["format"] } else { "jpeg" }
            $quality = if ($req.ContainsKey("quality") -and $null -ne $req["quality"]) { [int]$req["quality"] } else { 82 }
            $fg = [DesktopNative]::GetForegroundWindow()
            $bounds = [DesktopNative]::GetTargetCaptureBounds($fg, $monitor, $scope)
            $shot = [DesktopNative]::CaptureScreenshot($bounds.X, $bounds.Y, $bounds.Width, $bounds.Height, $maxWidth, $null, $format, $quality, $true)
            return @{
                originX = $shot.OriginX
                originY = $shot.OriginY
                screenWidth = $shot.ScreenWidth
                screenHeight = $shot.ScreenHeight
                imageWidth = $shot.ImageWidth
                imageHeight = $shot.ImageHeight
                mimeType = $shot.MimeType
                imageBase64 = $shot.ImageBase64
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
                mimeType = $shot.MimeType
                imageBase64 = $shot.ImageBase64
            }
        }
        "find_elements" {
            $query = if ($req.ContainsKey("query") -and $req["query"]) { [string]$req["query"] } else { "" }
            $controlType = if ($req.ContainsKey("controlType") -and $req["controlType"]) { [string]$req["controlType"] } else { "" }
            if ($query.Trim() -eq "" -and $controlType.Trim() -eq "") {
                throw "find_elements requires query and/or controlType."
            }
            $maxResults = if ($req.ContainsKey("maxResults") -and $null -ne $req["maxResults"]) { [int]$req["maxResults"] } else { 25 }
            $includeTaskbar = if ($req.ContainsKey("includeTaskbar")) { [bool]$req["includeTaskbar"] } else { $true }
            $els = [DesktopNative]::FindElements($query, $controlType, $maxResults, $includeTaskbar)
            return @{
                ok = $true
                count = $els.Count
                elements = $els
            }
        }
        "wait_for" {
            $titleContains = if ($req.ContainsKey("windowTitleContains") -and $req["windowTitleContains"]) { [string]$req["windowTitleContains"] } else { "" }
            $procName = if ($req.ContainsKey("processName") -and $req["processName"]) { [string]$req["processName"] } else { "" }
            $elContains = if ($req.ContainsKey("elementNameContains") -and $req["elementNameContains"]) { [string]$req["elementNameContains"] } else { "" }
            $screenChange = if ($req.ContainsKey("screenChange")) { [bool]$req["screenChange"] } else { $false }
            if ($titleContains -eq "" -and $procName -eq "" -and $elContains -eq "" -and -not $screenChange) {
                throw "wait_for requires at least one of windowTitleContains, processName, elementNameContains, or screenChange: true."
            }
            $timeoutMs = if ($req.ContainsKey("timeoutMs") -and $null -ne $req["timeoutMs"]) { [int]$req["timeoutMs"] } else { 5000 }
            $pollMs = if ($req.ContainsKey("pollMs") -and $null -ne $req["pollMs"]) { [int]$req["pollMs"] } else { 200 }
            $wf = [DesktopNative]::WaitForCondition($titleContains, $procName, $elContains, $screenChange, $timeoutMs, $pollMs)
            return @{
                ok = $true
                matched = $wf.Matched
                elapsedMs = $wf.ElapsedMs
                screenChanged = $wf.ScreenChanged
                window = $wf.Window
                element = $wf.Element
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
            $modVks = if ($req.ContainsKey("modifiers")) { Resolve-ModifierVks $req["modifiers"] } else { $null }
            [DesktopNative]::MouseClick($el.Cx, $el.Cy, $true, $button, $clicks, $true, $modVks)
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
            $directValue = if ($req.ContainsKey("directValue")) { [bool]$req["directValue"] } else { $false }

            $usedDirect = $false
            if ($directValue) {
                $usedDirect = [DesktopNative]::TrySetElementValueDirect($el.Cx, $el.Cy, $text)
            }
            if (-not $usedDirect) {
                [DesktopNative]::MouseClick($el.Cx, $el.Cy, $true, "left", 1, $true, $null)
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
                method = $(if ($usedDirect) { "uia_value" } elseif ($useClipboard) { "clipboard" } else { "unicode" })
            }
        }
        "mouse_click" {
            $hasPos = $req.ContainsKey("x") -and $req.ContainsKey("y") -and $null -ne $req["x"] -and $null -ne $req["y"]
            $x = if ($hasPos) { [int]$req["x"] } else { 0 }
            $y = if ($hasPos) { [int]$req["y"] } else { 0 }
            $button = if ($req.ContainsKey("button") -and $req["button"]) { [string]$req["button"] } else { "left" }
            $clicks = if ($req.ContainsKey("clicks") -and $req["clicks"]) { [int]$req["clicks"] } else { 1 }
            $smooth = if ($req.ContainsKey("smooth")) { [bool]$req["smooth"] } else { $true }
            $modVks = if ($req.ContainsKey("modifiers")) { Resolve-ModifierVks $req["modifiers"] } else { $null }
            [DesktopNative]::MouseClick($x, $y, $hasPos, $button, $clicks, $smooth, $modVks)
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
            $delta = if ($req.ContainsKey("delta") -and $null -ne $req["delta"]) { [int]$req["delta"] } else { 0 }
            $hDelta = if ($req.ContainsKey("horizontalDelta") -and $null -ne $req["horizontalDelta"]) { [int]$req["horizontalDelta"] } else { 0 }
            $hasPos = $req.ContainsKey("x") -and $req.ContainsKey("y") -and $null -ne $req["x"] -and $null -ne $req["y"]
            $x = if ($hasPos) { [int]$req["x"] } else { 0 }
            $y = if ($hasPos) { [int]$req["y"] } else { 0 }
            [DesktopNative]::MouseScroll($delta, $hDelta, $x, $y, $hasPos)
            return @{ ok = $true; delta = $delta; horizontalDelta = $hDelta }
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
            $target = if ($req.ContainsKey("target") -and $req["target"]) { ([string]$req["target"]).Trim() } else { "" }
            if ($target.Length -eq 0) { throw "launch_app requires a non-empty target." }
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
