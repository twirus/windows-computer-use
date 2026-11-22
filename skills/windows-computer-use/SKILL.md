---
name: windows-computer-use
description: >-
  Best practices and workflow for controlling the user's Windows desktop accurately
  and reliably using the windows-desktop MCP server (UI Automation + Set-of-Mark +
  visual AI overlay). Activate whenever the user asks to interact with Windows
  applications, desktop UI, windows, mouse, or keyboard.
---

# Windows Computer Use Playbook

You have a full Windows Computer Use MCP server (`windows-desktop` v3.3) with:
- **Native Windows UI Automation (Accessibility Tree)** + **Set-of-Mark (numbered boxes)** + element states (`[checked]`, `[selected]`, `[expanded]`, `[focused]`) via `desktop_state` and deep search via `find_elements`
- **Element-targeted actions** (`click_element`, `type_into_element` with optional `directValue: true` and `modifiers: ["ctrl"|"shift"|"alt"]`)
- **Smart waiting & batching** (`wait_for` with window/element/`screenChange`, `batch_actions` with `returnStateAfter: true`)
- **Direct app & window controls** (`launch_app`, `window_action`, `clipboard`, `wait`)
- **Live glowing screen border, AI cursor, click ripples & `Ctrl+Alt+X` user kill-switch** (`set_overlay`)

## Execution Mode

- By default, execute `windows-desktop` MCP tools **directly in the current conversation** (without spawning a subagent) using the currently selected model.
- Only delegate to a `desktop-operator` subagent when the user explicitly invokes `/pc-flash` (`Model: "flash"`), `/pc-pro` (`Model: "pro"`), or asks to use a subagent.

## Golden Rules for Reliable Computer Use

1. **Always start with `desktop_state` (not raw `get_screenshot`).**
   - `desktop_state` returns both the annotated screenshot with `[1]`, `[2]`, ... tags AND the exact list of interactive UI elements with names, types, values, and coordinates.
   - Use raw `mouse_click(x, y)` only as a fallback when a target (e.g., Canvas, game, custom UI) does not appear in the UI Automation tree.
   - When dealing with tiny icons, small text, or game/Canvas UIs, call `zoom_region(x, y)` to magnify that area 2.5× with a real-screen coordinate grid, then click precisely.

2. **Prefer `click_element` and `type_into_element` over raw coordinates.**
   - `click_element(elementId)` clicks the exact center of the element from UIA — zero misclicks.
   - `type_into_element(elementId, text, clearFirst, pressEnter)` clicks the field, clears it if needed, and pastes via clipboard (100% safe for Cyrillic, Unicode, and multi-line text regardless of RU/EN keyboard layout).

3. **Use `launch_app` and `window_action` instead of clicking Start Menu or window borders.**
   - To open Notepad, Chrome, Explorer, settings, or a URL: call `launch_app(target=...)` + `wait(ms=700)` + `desktop_state()`.
   - To switch or maximize a window: call `window_action(windowAction="focus"|"maximize", titleContains=...)`.

4. **Never accidentally close applications.**
   - Do NOT click window close `[X]` buttons or send `alt+f4` / `ctrl+w` / `ctrl+q` unless the user explicitly asked to close that app/tab.
   - Double-check element names in `desktop_state` before clicking anything near the top-right corner of a window.

5. **Be fast — batch predictable sequences with `batch_actions` and use `wait_for`.**
   - Whenever 2+ consecutive steps are predictable (e.g. switch tabs, click input → type → press Enter → wait → click back, or focus window → wait), combine them into a **single `batch_actions` call** instead of wasting multiple LLM round-trips.
   - Pass `returnStateAfter: true` on `batch_actions` when you need to inspect the result right after the batch (saves a full turn!), or `hideOverlayAfter: true` on the final call when no further steps are needed.
   - Use `wait_for(windowTitleContains|processName|elementNameContains)` instead of guessing long `wait(ms)` sleeps after launching apps or opening dialogs.
   - Use `desktop_state(scope="window")` for small dialogs/apps to get crisp, tightly cropped screenshots, or `desktop_state(includeScreenshot=false)` for quick text-only checks.

6. **Always verify and finish the task completely.**
   - After every significant action (click, submit, navigation, save), call `desktop_state` (with a short `wait` if an app is loading) to verify the UI actually updated as expected.
   - If a click didn't register (e.g., window wasn't focused or a dialog popped up), diagnose from the new `desktop_state` and retry smartly instead of giving up halfway.
   - Never stop early — continue the perceive → act → verify loop until the user's goal is visibly completed on screen.

7. **Respect the user kill-switch (`Ctrl+Alt+X`).**
   - If any tool returns `STOPPED_BY_USER`, stop immediately, do not retry actions, and ask the user how they would like to proceed.

8. **Clean up when done.**
   - Once the task is verified complete, call `set_overlay(visible=false)` so the glowing screen border disappears immediately instead of waiting for the idle timeout.

9. **Use the right tool for web vs desktop.**
   - For general web browsing / web apps, prefer the built-in browser subagent when appropriate; use `windows-desktop` for native Windows apps, OS settings, cross-app desktop workflows, or when the user specifically wants you to operate their live Windows desktop.
