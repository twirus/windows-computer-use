$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:logPath = Join-Path $PSScriptRoot "overlay.log"
function Write-Log([string]$msg) {
    try {
        $ts = (Get-Date).ToString("HH:mm:ss.fff")
        [System.IO.File]::AppendAllText($script:logPath, "[$ts] $msg`r`n", [System.Text.Encoding]::UTF8)
    } catch { }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions

$win32Code = @"
using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;
using System.Threading;

public static class OverlayNative {
    public static ConcurrentQueue<string> IncomingLines = new ConcurrentQueue<string>();
    public static volatile bool StdinClosed = false;

    public static void StartStdinReader() {
        Thread t = new Thread(() => {
            try {
                string line;
                while ((line = Console.In.ReadLine()) != null) {
                    string trimmed = line.Trim();
                    if (trimmed.Length > 0) IncomingLines.Enqueue(trimmed);
                }
            } catch { }
            StdinClosed = true;
        });
        t.IsBackground = true;
        t.Start();
    }

    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_TOOLWINDOW = 0x00000080;
    public const int WS_EX_TOPMOST = 0x00000008;
    public const int WS_EX_NOACTIVATE = 0x08000000;

    public const int SW_SHOWNOACTIVATE = 4;
    public const int SW_HIDE = 0;

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;

    public const int VK_CONTROL = 0x11;
    public const int VK_MENU = 0x12; // Alt
    public const int VK_X = 0x58;

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern IntPtr SetProcessDpiAwarenessContext(IntPtr value);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static void InitDpi() {
        try {
            SetProcessDpiAwarenessContext(new IntPtr(-4));
        } catch {
            try { SetProcessDPIAware(); } catch { }
        }
    }

    public static void MakeClickThrough(IntPtr hwnd) {
        int exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
        exStyle |= WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_NOACTIVATE;
        SetWindowLong(hwnd, GWL_EXSTYLE, exStyle);
    }

    public static void ForceShowTopmost(IntPtr hwnd, int x, int y, int w, int h) {
        MakeClickThrough(hwnd);
        ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        if (w > 0 && h > 0) {
            SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
        } else {
            SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
        }
    }

    public static void HideNative(IntPtr hwnd) {
        ShowWindow(hwnd, SW_HIDE);
    }

    public static bool IsAbortComboPressed() {
        bool ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
        bool alt = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
        bool x = (GetAsyncKeyState(VK_X) & 0x8000) != 0;
        return ctrl && alt && x;
    }
}
"@

Add-Type -TypeDefinition $win32Code -Language CSharp
[OverlayNative]::InitDpi()

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowInTaskbar="False"
        ShowActivated="False"
        IsHitTestVisible="False"
        ResizeMode="NoResize"
        WindowStartupLocation="Manual"
        Left="0"
        Top="0"
        Width="1280"
        Height="720">
    <Grid x:Name="RootGrid" Opacity="1" IsHitTestVisible="False">
        <!-- Subtle inner edge tint (Claude-style warm amber, clean and non-neon) -->
        <Border BorderThickness="6"
                BorderBrush="#22D97757"
                IsHitTestVisible="False"/>

        <!-- Crisp minimalist 2.5px frame -->
        <Border x:Name="MainFrameBorder"
                BorderThickness="2.5"
                BorderBrush="#E6D97757"
                Opacity="0.92"
                IsHitTestVisible="False"/>

        <!-- Slim, unobtrusive top status bar -->
        <Border x:Name="StatusPill"
                HorizontalAlignment="Center"
                VerticalAlignment="Top"
                Margin="0,8,0,0"
                Padding="11,4.5,11,4.5"
                CornerRadius="10"
                Background="#E618181B"
                BorderBrush="#33FFFFFF"
                BorderThickness="1"
                IsHitTestVisible="False">
            <Border.Effect>
                <DropShadowEffect Color="#000000" BlurRadius="12" ShadowDepth="2" Opacity="0.45"/>
            </Border.Effect>
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                <Ellipse x:Name="StatusDot" Width="7.5" Height="7.5" Margin="0,0,8,0" Fill="#D97757"/>
                <TextBlock x:Name="StatusText"
                           Text="Управление активно"
                           Foreground="#F4F4F5"
                           FontFamily="Segoe UI"
                           FontSize="12"
                           MaxWidth="820"
                           TextTrimming="CharacterEllipsis"
                           VerticalAlignment="Center"/>
                <Border Margin="10,0,0,0"
                        Padding="6,1.5,6,1.5"
                        CornerRadius="5"
                        Background="#18FFFFFF">
                    <TextBlock Text="Ctrl+Alt+X"
                               Foreground="#A1A1AA"
                               FontFamily="Segoe UI"
                               FontSize="10.5"
                               VerticalAlignment="Center"/>
                </Border>
            </StackPanel>
        </Border>

        <!-- Layer for subtle cursor badge and click ripples (no duplicate arrow!) -->
        <Canvas x:Name="EffectsCanvas" IsHitTestVisible="False">
            <Grid x:Name="CursorTag" Visibility="Collapsed" IsHitTestVisible="False">
                <Canvas Width="260" Height="44">
                    <!-- Subtle ring around the real Windows cursor tip -->
                    <Ellipse Canvas.Left="-10" Canvas.Top="-10"
                             Width="20" Height="20"
                             Stroke="#CCD97757"
                             StrokeThickness="1.5"
                             Fill="Transparent"/>
                    <!-- Clean Figma/Claude-style floating label offset from real cursor -->
                    <Border Canvas.Left="18" Canvas.Top="18"
                            Padding="7,2.5,7,2.5"
                            CornerRadius="6"
                            Background="#E818181B"
                            BorderBrush="#40D97757"
                            BorderThickness="1">
                        <Border.Effect>
                            <DropShadowEffect Color="#000000" BlurRadius="8" ShadowDepth="2" Opacity="0.4"/>
                        </Border.Effect>
                        <TextBlock x:Name="CursorLabel"
                                   Text="Клик"
                                   Foreground="#F4F4F5"
                                   FontFamily="Segoe UI"
                                   FontSize="11"
                                   MaxWidth="210"
                                   TextTrimming="CharacterEllipsis"/>
                    </Border>
                </Canvas>
            </Grid>
        </Canvas>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

$primaryBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$script:monX = $primaryBounds.X
$script:monY = $primaryBounds.Y
$script:monW = $primaryBounds.Width
$script:monH = $primaryBounds.Height

$mainFrame = $window.FindName("MainFrameBorder")
$statusDot = $window.FindName("StatusDot")
$statusText = $window.FindName("StatusText")
$effectsCanvas = $window.FindName("EffectsCanvas")
$cursorTag = $window.FindName("CursorTag")
$cursorLabel = $window.FindName("CursorLabel")

# Gentle, calm breathing on border and status dot
$frameAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
$frameAnim.From = 0.76
$frameAnim.To = 0.96
$frameAnim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(1800))
$frameAnim.AutoReverse = $true
$frameAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
$mainFrame.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $frameAnim)

$dotAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
$dotAnim.From = 0.45
$dotAnim.To = 1.0
$dotAnim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(1100))
$dotAnim.AutoReverse = $true
$dotAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
$statusDot.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $dotAnim)

$script:isVisible = $false
$script:lastActivity = [DateTime]::UtcNow
$script:lastCursorMove = [DateTime]::MinValue
$script:autoHideSeconds = 15
$script:cursorTagHideSeconds = 1.8
$script:abortCooldownUntil = [DateTime]::MinValue
$script:hwnd = [IntPtr]::Zero

$window.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
    $script:hwnd = $helper.Handle
    [OverlayNative]::MakeClickThrough($script:hwnd)
})

function Get-DpiScale() {
    $src = [System.Windows.PresentationSource]::FromVisual($window)
    if ($null -ne $src -and $null -ne $src.CompositionTarget) {
        $m = $src.CompositionTarget.TransformToDevice
        if ($m.M11 -gt 0 -and $m.M22 -gt 0) {
            return @{ X = $m.M11; Y = $m.M22 }
        }
    }
    return @{ X = 1.0; Y = 1.0 }
}

function Apply-WindowDipBounds() {
    $scale = Get-DpiScale
    $window.Left = [double]$script:monX / $scale.X
    $window.Top = [double]$script:monY / $scale.Y
    $window.Width = [double]$script:monW / $scale.X
    $window.Height = [double]$script:monH / $scale.Y
}

function Set-MonitorBounds([int]$x, [int]$y, [int]$w, [int]$h) {
    if ($w -le 0 -or $h -le 0) { return }
    $script:monX = $x
    $script:monY = $y
    $script:monW = $w
    $script:monH = $h
    if ($script:isVisible) {
        Apply-WindowDipBounds
        if ($script:hwnd -ne [IntPtr]::Zero) {
            [OverlayNative]::ForceShowTopmost($script:hwnd, $script:monX, $script:monY, $script:monW, $script:monH)
        }
    }
}

function Show-Overlay([string]$text) {
    $script:lastActivity = [DateTime]::UtcNow
    if ($text -and $text.Length -gt 0) {
        $statusText.Text = $text
    }
    if (-not $script:isVisible) {
        $script:isVisible = $true
        $window.Visibility = [System.Windows.Visibility]::Visible
        $window.Show()
        Apply-WindowDipBounds
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        $script:hwnd = $helper.Handle
        [OverlayNative]::ForceShowTopmost($script:hwnd, $script:monX, $script:monY, $script:monW, $script:monH)
    } else {
        Apply-WindowDipBounds
        if ($script:hwnd -ne [IntPtr]::Zero) {
            [OverlayNative]::ForceShowTopmost($script:hwnd, $script:monX, $script:monY, $script:monW, $script:monH)
        }
    }
}

function Hide-Overlay() {
    if (-not $script:isVisible) { return }
    $script:isVisible = $false
    $cursorTag.Visibility = [System.Windows.Visibility]::Collapsed
    $window.Hide()
    if ($script:hwnd -ne [IntPtr]::Zero) {
        [OverlayNative]::HideNative($script:hwnd)
    }
}

function Convert-PhysicalToLocalDip([double]$px, [double]$py) {
    $scale = Get-DpiScale
    $relX = ($px - $script:monX) / $scale.X
    $relY = ($py - $script:monY) / $scale.Y
    return [System.Windows.Point]::new($relX, $relY)
}

function Move-CursorTag([double]$px, [double]$py, [string]$label) {
    $scr = [System.Windows.Forms.Screen]::FromPoint([System.Drawing.Point]::new([int]$px, [int]$py))
    if ($null -ne $scr) {
        $b = $scr.Bounds
        if ($b.X -ne $script:monX -or $b.Y -ne $script:monY -or $b.Width -ne $script:monW -or $b.Height -ne $script:monH) {
            Set-MonitorBounds $b.X $b.Y $b.Width $b.Height
        }
    }
    Show-Overlay ""
    $script:lastCursorMove = [DateTime]::UtcNow
    $pt = Convert-PhysicalToLocalDip $px $py
    $cursorLabel.Text = if ($label -and $label.Length -gt 0) { $label } else { "Действие" }

    if ($cursorTag.Visibility -ne [System.Windows.Visibility]::Visible) {
        [System.Windows.Controls.Canvas]::SetLeft($cursorTag, $pt.X)
        [System.Windows.Controls.Canvas]::SetTop($cursorTag, $pt.Y)
        $cursorTag.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $curLeft = [System.Windows.Controls.Canvas]::GetLeft($cursorTag)
        $curTop = [System.Windows.Controls.Canvas]::GetTop($cursorTag)
        if ([double]::IsNaN($curLeft)) { $curLeft = $pt.X }
        if ([double]::IsNaN($curTop)) { $curTop = $pt.Y }

        $dur = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(100))
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut

        $animX = New-Object System.Windows.Media.Animation.DoubleAnimation($curLeft, $pt.X, $dur)
        $animX.EasingFunction = $ease
        $animY = New-Object System.Windows.Media.Animation.DoubleAnimation($curTop, $pt.Y, $dur)
        $animY.EasingFunction = $ease

        $cursorTag.BeginAnimation([System.Windows.Controls.Canvas]::LeftProperty, $animX)
        $cursorTag.BeginAnimation([System.Windows.Controls.Canvas]::TopProperty, $animY)
    }
}

function Spawn-Ripple([double]$px, [double]$py, [string]$button) {
    Show-Overlay ""
    $pt = Convert-PhysicalToLocalDip $px $py

    $colorHex = "#D97757"
    if ($button -eq "right") { $colorHex = "#E4E4E7" }
    elseif ($button -eq "middle") { $colorHex = "#A1A1AA" }

    $brush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($colorHex)

    $ellipse = New-Object System.Windows.Shapes.Ellipse
    $ellipse.Width = 14
    $ellipse.Height = 14
    $ellipse.Stroke = $brush
    $ellipse.StrokeThickness = 2
    $ellipse.Fill = [System.Windows.Media.Brushes]::Transparent
    $ellipse.IsHitTestVisible = $false

    $scale = New-Object System.Windows.Media.ScaleTransform(1.0, 1.0)
    $ellipse.RenderTransformOrigin = [System.Windows.Point]::new(0.5, 0.5)
    $ellipse.RenderTransform = $scale

    [System.Windows.Controls.Canvas]::SetLeft($ellipse, $pt.X - 7)
    [System.Windows.Controls.Canvas]::SetTop($ellipse, $pt.Y - 7)
    [void]$effectsCanvas.Children.Add($ellipse)

    $dur = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(360))
    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut

    $animScale = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 3.6, $dur)
    $animScale.EasingFunction = $ease
    $animOp = New-Object System.Windows.Media.Animation.DoubleAnimation(0.9, 0.0, $dur)
    $animOp.Add_Completed({
        $effectsCanvas.Children.Remove($ellipse)
    })

    $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animScale)
    $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animScale)
    $ellipse.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animOp)
}

$script:ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer

function Process-OverlayCommand([string]$trimmed) {
    try {
        $cmd = $script:ser.DeserializeObject($trimmed)
        $type = [string]$cmd["type"]
        switch ($type) {
            "bounds" {
                Set-MonitorBounds ([int]$cmd["x"]) ([int]$cmd["y"]) ([int]$cmd["width"]) ([int]$cmd["height"])
            }
            "show" {
                if ($cmd.ContainsKey("x") -and $cmd.ContainsKey("width")) {
                    Set-MonitorBounds ([int]$cmd["x"]) ([int]$cmd["y"]) ([int]$cmd["width"]) ([int]$cmd["height"])
                }
                $txt = if ($cmd.ContainsKey("status")) { [string]$cmd["status"] } else { "" }
                Show-Overlay $txt
            }
            "status" {
                $txt = if ($cmd.ContainsKey("status")) { [string]$cmd["status"] } else { "" }
                Show-Overlay $txt
            }
            "hide" {
                Hide-Overlay
            }
            "cursor" {
                $x = [double]$cmd["x"]
                $y = [double]$cmd["y"]
                $lbl = if ($cmd.ContainsKey("label")) { [string]$cmd["label"] } else { "Наведение" }
                $st = if ($cmd.ContainsKey("status")) { [string]$cmd["status"] } else { "" }
                if ($st) { Show-Overlay $st }
                Move-CursorTag $x $y $lbl
            }
            "click" {
                $x = [double]$cmd["x"]
                $y = [double]$cmd["y"]
                $btn = if ($cmd.ContainsKey("button")) { [string]$cmd["button"] } else { "left" }
                $lbl = if ($cmd.ContainsKey("label")) { [string]$cmd["label"] } else { "Клик" }
                $st = if ($cmd.ContainsKey("status")) { [string]$cmd["status"] } else { "" }
                if ($st) { Show-Overlay $st }
                Move-CursorTag $x $y $lbl
                Spawn-Ripple $x $y $btn
            }
            "quit" {
                $timer.Stop()
                $window.Close()
                [System.Windows.Application]::Current.Shutdown()
            }
        }
    } catch {
        Write-Log "Command error: $($_.Exception.Message)"
    }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(25)
$timer.Add_Tick({
    $line = $null
    while ([OverlayNative]::IncomingLines.TryDequeue([ref]$line)) {
        Process-OverlayCommand $line
    }
    if ([OverlayNative]::StdinClosed) {
        $timer.Stop()
        $window.Close()
        [System.Windows.Application]::Current.Shutdown()
        return
    }
    $now = [DateTime]::UtcNow
    if ($script:isVisible) {
        if ([OverlayNative]::IsAbortComboPressed() -and $now -gt $script:abortCooldownUntil) {
            $script:abortCooldownUntil = $now.AddSeconds(1.5)
            Hide-Overlay
            [Console]::Out.WriteLine('{"event":"abort"}')
            [Console]::Out.Flush()
            return
        }
        if ($cursorTag.Visibility -eq [System.Windows.Visibility]::Visible -and ($now - $script:lastCursorMove).TotalSeconds -ge $script:cursorTagHideSeconds) {
            $cursorTag.Visibility = [System.Windows.Visibility]::Collapsed
        }
        if (($now - $script:lastActivity).TotalSeconds -ge $script:autoHideSeconds) {
            Hide-Overlay
        }
    }
})
$timer.Start()

[OverlayNative]::StartStdinReader()

[Console]::Out.WriteLine('{"ready":true}')
[Console]::Out.Flush()

$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
[void]$app.Run()
