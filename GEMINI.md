# GEMINI.md — Project Guidelines for Windows Computer Use

This repository contains the `windows-desktop` MCP server (v3.1+) for Antigravity.

## Critical Architectural Rules (Do Not Break!)

1. **Zero external npm / Python dependencies:**
   - `src/server.js` must remain pure Node.js ESM (`"type": "module"`) using newline-delimited JSON-RPC 2.0 over `stdio`.
   - `src/desktop_worker.ps1` and `src/overlay.ps1` rely exclusively on built-in Windows PowerShell 5.1 + .NET Framework assemblies (`PresentationFramework`, `UIAutomationClient`, `System.Windows.Forms`, `System.Drawing`).

2. **Known Win32 / WPF / Electron pitfalls (already solved — keep them intact!):**
   - **Never use `AttachThreadInput` or unnecessary `ShowWindow(SW_SHOW)` in `FocusWindow`:** it hides/minimizes Electron apps like Discord to the system tray. Keep `SwitchToThisWindow` + `SetForegroundWindow`.
   - **Never use raw `System.Threading.Thread` with a PowerShell scriptblock in `overlay.ps1`:** PowerShell threads without a Runspace silently crash. Keep the C# `OverlayNative.StartStdinReader()` + `ConcurrentQueue<string>` polled by `DispatcherTimer`.
   - **Never call `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` on a WPF window with `AllowsTransparency="True"`:** DWM rejects it on layered per-pixel alpha windows.
   - **Always use `ShowWindow(hwnd, SW_SHOWNOACTIVATE)` + `SetWindowPos(HWND_TOPMOST, ...)` in `overlay.ps1`:** Node's `windowsHide: true` causes WPF's first `$window.Show()` to remain hidden otherwise.
   - **Multi-monitor negative coordinates (`X < 0`):** always account for `originX` / `originY` in screenshots, UIA filtering, `CaptureZoomRegion` (`Math.Ceiling`), and `mapCoords`.
   - **Key combos in Chrome/Electron:** `SendKeyCombo` must keep short delays (~14–16ms) between key-down and key-up; single-packet 0ms `SendInput` combos get dropped by Chrome.

3. **Safety invariants:**
   - Never allow accidental app closures (`alt+f4`, `ctrl+w`, `ctrl+q` in any key order, `window_action(close)`, or clicking `Close`/`Закрыть` buttons) without explicit `allowClose: true` / `confirmClose: true`.
   - Always preserve the `Ctrl+Alt+X` abort kill-switch and check `assertNotAborted()` before mutating actions and inside `batch_actions` loops.
   - Always clean up child PowerShell processes synchronously on `stdin.end`, `SIGINT`, `SIGTERM`, and `exit`.

## Standard Development Workflow

After making changes:
1. Run `npm run check` and `npm test` — all tests must pass with exit code 0.
2. If `skills/` were modified, run `npm run sync-skills` to update `~/.gemini/config/skills/`.
3. If preparing a release for sharing, run `npm run build` to regenerate `dist/windows-computer-use-antigravity.zip`.
4. Remind the user to restart the `windows-desktop` MCP server (or Antigravity) for `src/` changes to take effect.
