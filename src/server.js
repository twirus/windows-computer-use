import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WORKER_PATH = path.join(__dirname, "desktop_worker.ps1");
const OVERLAY_PATH = path.join(__dirname, "overlay.ps1");

let lastScreenMeta = null;
let abortedByUser = false;

class OverlayController {
  constructor() {
    this.proc = null;
    this.ready = false;
    this.stdoutBuf = "";
    this.disabled = false;
    this.start();
  }

  start() {
    if (this.proc || this.disabled) return;
    this.ready = false;
    this.stdoutBuf = "";

    try {
      const child = spawn(
        "powershell.exe",
        [
          "-NoProfile",
          "-STA",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          OVERLAY_PATH,
        ],
        {
          windowsHide: true,
          stdio: ["pipe", "pipe", "pipe"],
        }
      );

      this.proc = child;
      child.stdout.setEncoding("utf8");
      child.stderr.setEncoding("utf8");

      child.stderr.on("data", (chunk) => {
        process.stderr.write(`[overlay stderr] ${chunk}`);
      });

      child.stdout.on("data", (chunk) => {
        this.stdoutBuf += chunk;
        let idx;
        while ((idx = this.stdoutBuf.indexOf("\n")) !== -1) {
          const line = this.stdoutBuf.slice(0, idx).trim();
          this.stdoutBuf = this.stdoutBuf.slice(idx + 1);
          if (!line) continue;
          try {
            const msg = JSON.parse(line);
            if (msg.ready) {
              this.ready = true;
            } else if (msg.event === "abort") {
              abortedByUser = true;
              process.stderr.write("[overlay] User pressed Ctrl+Alt+X abort hotkey\n");
            }
          } catch {}
        }
      });

      child.on("exit", () => {
        this.proc = null;
        this.ready = false;
      });

      child.on("error", () => {
        this.proc = null;
        this.ready = false;
      });
    } catch {
      this.proc = null;
      this.ready = false;
    }
  }

  send(payload) {
    if (this.disabled) return;
    if (!this.proc) this.start();
    if (!this.proc || !this.proc.stdin || this.proc.stdin.destroyed) return;
    try {
      this.proc.stdin.write(JSON.stringify(payload) + "\n", "utf8");
    } catch {}
  }

  show(status = "Активен", bounds = null) {
    if (bounds && bounds.width > 0 && bounds.height > 0) {
      this.send({ type: "show", status, x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height });
    } else {
      this.send({ type: "show", status });
    }
  }

  hide() {
    this.send({ type: "hide" });
  }

  cursor(x, y, label = "AI", status = "") {
    this.send({ type: "cursor", x, y, label, status });
  }

  click(x, y, button = "left", label = "Клик", status = "") {
    this.send({ type: "click", x, y, button, label, status });
  }

  kill() {
    try {
      if (this.proc) {
        try {
          if (this.proc.stdin && !this.proc.stdin.destroyed) {
            this.proc.stdin.end();
          }
        } catch {}
        try {
          this.proc.kill();
        } catch {}
        this.proc = null;
        this.ready = false;
      }
    } catch {}
  }
}

class PersistentWorker {
  constructor() {
    this.proc = null;
    this.ready = false;
    this.readyPromise = null;
    this.nextId = 1;
    this.pending = new Map();
    this.stdoutBuf = "";
    this.start();
  }

  start() {
    if (this.proc) return this.readyPromise;
    this.ready = false;
    this.stdoutBuf = "";

    this.readyPromise = new Promise((resolveReady, rejectReady) => {
      const child = spawn(
        "powershell.exe",
        [
          "-NoProfile",
          "-NonInteractive",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          WORKER_PATH,
        ],
        {
          windowsHide: true,
          stdio: ["pipe", "pipe", "pipe"],
        }
      );

      this.proc = child;
      child.stdout.setEncoding("utf8");
      child.stderr.setEncoding("utf8");

      let stderrTail = "";
      child.stderr.on("data", (chunk) => {
        stderrTail = (stderrTail + chunk).slice(-2000);
        process.stderr.write(`[worker stderr] ${chunk}`);
      });

      child.stdout.on("data", (chunk) => {
        this.stdoutBuf += chunk;
        let idx;
        while ((idx = this.stdoutBuf.indexOf("\n")) !== -1) {
          const line = this.stdoutBuf.slice(0, idx).trim();
          this.stdoutBuf = this.stdoutBuf.slice(idx + 1);
          if (!line) continue;

          let msg;
          try {
            msg = JSON.parse(line);
          } catch {
            continue;
          }

          if (!this.ready && msg.ready) {
            this.ready = true;
            resolveReady();
            continue;
          }

          if (msg.id !== undefined && msg.id !== null) {
            const entry = this.pending.get(msg.id);
            if (entry) {
              this.pending.delete(msg.id);
              clearTimeout(entry.timer);
              if (msg.ok) {
                entry.resolve(msg.result);
              } else {
                entry.reject(new Error(msg.error || "Worker command failed"));
              }
            }
          }
        }
      });

      child.on("exit", (code, signal) => {
        const err = new Error(
          `Desktop worker exited (code=${code}, signal=${signal})${stderrTail ? `: ${stderrTail.trim()}` : ""}`
        );
        if (!this.ready) {
          rejectReady(err);
        }
        for (const [, entry] of this.pending) {
          clearTimeout(entry.timer);
          entry.reject(err);
        }
        this.pending.clear();
        this.proc = null;
        this.ready = false;
        this.readyPromise = null;
      });

      child.on("error", (err) => {
        if (!this.ready) rejectReady(err);
      });
    });

    return this.readyPromise;
  }

  async call(payload, timeoutMs = 30000) {
    if (!this.proc || !this.readyPromise) {
      this.start();
    }
    await this.readyPromise;

    const id = this.nextId++;
    const req = { ...payload, id };

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Worker request timed out after ${timeoutMs}ms`));
      }, timeoutMs);

      this.pending.set(id, { resolve, reject, timer });
      try {
        this.proc.stdin.write(JSON.stringify(req) + "\n", "utf8");
      } catch (err) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(err);
      }
    });
  }
}

const worker = new PersistentWorker();
const overlay = new OverlayController();

function mapCoords(x, y, coordSpace = "image") {
  if (typeof x !== "number" || typeof y !== "number") {
    return null;
  }
  if (
    coordSpace === "image" &&
    lastScreenMeta &&
    lastScreenMeta.imageWidth > 0 &&
    lastScreenMeta.imageHeight > 0
  ) {
    const ox = lastScreenMeta.originX || 0;
    const oy = lastScreenMeta.originY || 0;
    const sx = ox + Math.round((x * lastScreenMeta.screenWidth) / lastScreenMeta.imageWidth);
    const sy = oy + Math.round((y * lastScreenMeta.screenHeight) / lastScreenMeta.imageHeight);
    return { x: sx, y: sy };
  }
  return { x: Math.round(x), y: Math.round(y) };
}

function isDangerousCloseCombo(keys) {
  const parts = String(keys || "")
    .toLowerCase()
    .split("+")
    .map((s) => s.trim())
    .filter(Boolean)
    .map((k) => {
      if (k === "control") return "ctrl";
      if (k === "menu") return "alt";
      return k;
    });
  const set = new Set(parts);
  if (set.has("alt") && set.has("f4")) return true;
  if (set.has("ctrl") && (set.has("w") || set.has("q"))) return true;
  return false;
}

function assertNotAborted() {
  if (abortedByUser) {
    throw new Error(
      "STOPPED_BY_USER: The user pressed Ctrl+Alt+X to stop AI computer control. Stop immediately and ask the user how to proceed. Call set_overlay(visible: true, resetAbort: true) only after the user asks to resume."
    );
  }
}

function formatElementsSummary(elements) {
  if (!elements || elements.length === 0) return "(no UI Automation elements detected — use visual coordinates from screenshot)";
  return elements
    .map((el) => {
      const namePart = el.Name ? `"${el.Name}"` : "(unnamed)";
      const valPart = el.Value ? ` val="${el.Value}"` : "";
      return `[${el.Id}] ${el.Type} ${namePart}${valPart} @(${el.Cx},${el.Cy} ${el.Width}x${el.Height})`;
    })
    .join("\n");
}

function normalizeBatchItem(item) {
  const type = String(item.type || item.action || "").toLowerCase();
  const cs = item.coordSpace || "image";

  switch (type) {
    case "click_element": {
      return {
        action: "click_element",
        elementId: Number(item.elementId ?? item.id),
        button: item.button || "left",
        clicks: item.clicks || 1,
        allowClose: Boolean(item.allowClose),
      };
    }
    case "type_into_element": {
      return {
        action: "type_into_element",
        elementId: Number(item.elementId ?? item.id),
        text: String(item.text ?? ""),
        clearFirst: Boolean(item.clearFirst),
        pressEnter: Boolean(item.pressEnter),
        useClipboard: item.useClipboard !== false,
      };
    }
    case "click":
    case "mouse_click": {
      const pos =
        typeof item.x === "number" && typeof item.y === "number"
          ? mapCoords(item.x, item.y, cs)
          : null;
      return {
        action: "mouse_click",
        ...(pos ? { x: pos.x, y: pos.y } : {}),
        button: item.button || "left",
        clicks: item.clicks || 1,
        smooth: item.smooth !== false,
      };
    }
    case "move":
    case "mouse_move": {
      const pos = mapCoords(item.x, item.y, cs);
      if (!pos) throw new Error("move requires numeric x and y");
      return { action: "mouse_move", x: pos.x, y: pos.y, smooth: item.smooth !== false };
    }
    case "drag":
    case "mouse_drag": {
      const p1 = mapCoords(item.x1, item.y1, cs);
      const p2 = mapCoords(item.x2, item.y2, cs);
      if (!p1 || !p2) throw new Error("drag requires numeric x1, y1, x2, y2");
      return {
        action: "mouse_drag",
        x1: p1.x,
        y1: p1.y,
        x2: p2.x,
        y2: p2.y,
        button: item.button || "left",
        steps: typeof item.steps === "number" ? item.steps : 20,
        durationMs: typeof item.durationMs === "number" ? item.durationMs : 180,
      };
    }
    case "scroll":
    case "mouse_scroll": {
      const pos =
        typeof item.x === "number" && typeof item.y === "number"
          ? mapCoords(item.x, item.y, cs)
          : null;
      return {
        action: "mouse_scroll",
        delta: Number(item.delta || 0),
        ...(pos ? { x: pos.x, y: pos.y } : {}),
      };
    }
    case "type":
    case "type_text": {
      return {
        action: "type_text",
        text: String(item.text ?? ""),
        ...(typeof item.useClipboard === "boolean" ? { useClipboard: item.useClipboard } : {}),
        pressEnter: Boolean(item.pressEnter),
      };
    }
    case "key":
    case "key_press": {
      const keys = String(item.keys ?? "");
      if (isDangerousCloseCombo(keys) && !item.allowClose) {
        throw new Error(`Blocked potentially unintended close shortcut "${keys}". Pass allowClose: true only if closing is explicitly requested.`);
      }
      return { action: "key_press", keys };
    }
    case "sleep":
    case "wait": {
      const ms = Math.max(0, Math.min(15000, Number(item.ms ?? 250)));
      return { action: "sleep", ms };
    }
    case "focus":
    case "focus_window": {
      return {
        action: "focus_window",
        titleContains: item.titleContains,
        processName: item.processName,
        handle: item.handle,
      };
    }
    case "window_action": {
      const wa = String(item.windowAction || "focus").toLowerCase();
      if (wa === "close" && !item.confirmClose) {
        throw new Error("Refusing to close window in batch without confirmClose: true.");
      }
      return {
        action: "window_action",
        windowAction: wa,
        titleContains: item.titleContains,
        processName: item.processName,
        handle: item.handle,
        x: item.x,
        y: item.y,
        width: item.width,
        height: item.height,
      };
    }
    case "launch":
    case "launch_app": {
      return {
        action: "launch_app",
        target: String(item.target ?? ""),
        args: item.args ? String(item.args) : "",
      };
    }
    default:
      throw new Error(`Unsupported batch action type: ${type}`);
  }
}

const TOOLS = [
  {
    name: "desktop_state",
    description:
      "PRIMARY TOOL: Inspect the Windows desktop using native UI Automation (Accessibility Tree) + an annotated Set-of-Mark screenshot (with numbered boxes [1], [2], ...). Returns active window, open windows, interactive UI elements with IDs/names/coordinates, and the annotated PNG. Always prefer this over raw get_screenshot so you can use click_element and type_into_element reliably.",
    inputSchema: {
      type: "object",
      properties: {
        includeScreenshot: {
          type: "boolean",
          default: true,
          description: "Whether to include a screenshot image (default true).",
        },
        annotated: {
          type: "boolean",
          default: true,
          description: "Overlay numbered Set-of-Mark bounding boxes on the screenshot (default true).",
        },
        maxWidth: {
          type: "integer",
          default: 1280,
          description: "Max width of screenshot in pixels (default 1280).",
        },
        maxElements: {
          type: "integer",
          default: 80,
          description: "Max interactive UI elements to collect (default 80).",
        },
        includeTaskbar: {
          type: "boolean",
          default: true,
          description: "Also include Windows taskbar buttons (default true).",
        },
      },
    },
  },
  {
    name: "click_element",
    description:
      "Click an interactive UI element by its numeric ID from the most recent desktop_state call. Much more accurate than guessing raw pixel coordinates.",
    inputSchema: {
      type: "object",
      properties: {
        elementId: { type: "integer", description: "Element ID from desktop_state (e.g. 12)." },
        button: { type: "string", enum: ["left", "right", "middle"], default: "left" },
        clicks: { type: "integer", default: 1, description: "1 for single click, 2 for double click." },
        allowClose: { type: "boolean", default: false, description: "Must be true to click a window Close button." },
      },
      required: ["elementId"],
    },
  },
  {
    name: "type_into_element",
    description:
      "Click a text input element by its ID from desktop_state, optionally clear it, paste/type text (100% Cyrillic & Unicode safe via clipboard), and optionally press Enter.",
    inputSchema: {
      type: "object",
      properties: {
        elementId: { type: "integer", description: "Element ID from desktop_state." },
        text: { type: "string", description: "Text to enter." },
        clearFirst: { type: "boolean", default: false, description: "Select all and clear before typing." },
        pressEnter: { type: "boolean", default: false, description: "Press Enter after typing." },
        useClipboard: { type: "boolean", default: true, description: "Paste via clipboard with restore (best for Russian/Unicode)." },
      },
      required: ["elementId", "text"],
    },
  },
  {
    name: "launch_app",
    description:
      "Launch a Windows application, file, folder, or URL directly (e.g. 'notepad', 'calc', 'explorer', 'https://...', or full path to .exe). Faster and more reliable than clicking Start Menu.",
    inputSchema: {
      type: "object",
      properties: {
        target: { type: "string", description: "Executable name, path, or URL." },
        args: { type: "string", description: "Optional command line arguments." },
      },
      required: ["target"],
    },
  },
  {
    name: "window_action",
    description:
      "Control a window: focus, maximize, minimize, restore, move_resize, or close (close requires confirmClose: true to prevent accidental app closures).",
    inputSchema: {
      type: "object",
      properties: {
        windowAction: {
          type: "string",
          enum: ["focus", "maximize", "minimize", "restore", "move_resize", "close"],
        },
        titleContains: { type: "string", description: "Substring of window title." },
        processName: { type: "string", description: "Process name (e.g. 'chrome', 'notepad')." },
        handle: { type: "integer", description: "Exact window handle." },
        x: { type: "integer" },
        y: { type: "integer" },
        width: { type: "integer" },
        height: { type: "integer" },
        confirmClose: {
          type: "boolean",
          default: false,
          description: "Must be true when windowAction is 'close'.",
        },
      },
      required: ["windowAction"],
    },
  },
  {
    name: "clipboard",
    description: "Read or write the Windows clipboard text.",
    inputSchema: {
      type: "object",
      properties: {
        mode: { type: "string", enum: ["get", "set"], default: "get" },
        text: { type: "string", description: "Text to copy when mode is 'set'." },
      },
      required: ["mode"],
    },
  },
  {
    name: "wait",
    description: "Wait for a specified number of milliseconds (e.g. while an app or page loads).",
    inputSchema: {
      type: "object",
      properties: {
        ms: { type: "integer", default: 500, description: "Milliseconds to wait (max 15000)." },
      },
      required: ["ms"],
    },
  },
  {
    name: "set_overlay",
    description:
      "Show or hide the glowing AI Computer Use screen border & status pill. Call with visible: false when you finish controlling the computer.",
    inputSchema: {
      type: "object",
      properties: {
        visible: { type: "boolean", description: "true to show, false to hide." },
        status: { type: "string", description: "Optional short status message shown in the top pill." },
        resetAbort: { type: "boolean", default: false, description: "Reset Ctrl+Alt+X user abort state." },
      },
      required: ["visible"],
    },
  },
  {
    name: "get_screenshot",
    description:
      "Capture a clean screenshot of the primary Windows display (overlay is automatically excluded). For most tasks prefer desktop_state instead.",
    inputSchema: {
      type: "object",
      properties: {
        maxWidth: { type: "integer", default: 1280 },
      },
    },
  },
  {
    name: "mouse_click",
    description: "Move smoothly to (x, y) and click. Prefer click_element when the target is in desktop_state.",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number" },
        y: { type: "number" },
        coordSpace: { type: "string", enum: ["image", "screen"], default: "image" },
        button: { type: "string", enum: ["left", "right", "middle"], default: "left" },
        clicks: { type: "integer", default: 1 },
        smooth: { type: "boolean", default: true },
      },
    },
  },
  {
    name: "mouse_move",
    description: "Move the mouse cursor smoothly to (x, y).",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number" },
        y: { type: "number" },
        coordSpace: { type: "string", enum: ["image", "screen"], default: "image" },
        smooth: { type: "boolean", default: true },
      },
      required: ["x", "y"],
    },
  },
  {
    name: "mouse_drag",
    description: "Drag mouse from (x1, y1) to (x2, y2).",
    inputSchema: {
      type: "object",
      properties: {
        x1: { type: "number" },
        y1: { type: "number" },
        x2: { type: "number" },
        y2: { type: "number" },
        coordSpace: { type: "string", enum: ["image", "screen"], default: "image" },
        button: { type: "string", enum: ["left", "right", "middle"], default: "left" },
        steps: { type: "integer", default: 20 },
        durationMs: { type: "integer", default: 180 },
      },
      required: ["x1", "y1", "x2", "y2"],
    },
  },
  {
    name: "mouse_path",
    description: "Move mouse along a polyline path of points.",
    inputSchema: {
      type: "object",
      properties: {
        points: {
          type: "array",
          items: {
            type: "object",
            properties: { x: { type: "number" }, y: { type: "number" } },
            required: ["x", "y"],
          },
        },
        coordSpace: { type: "string", enum: ["image", "screen"], default: "image" },
        button: { type: "string", enum: ["left", "right", "middle"], default: "left" },
        holdButton: { type: "boolean", default: true },
        stepDelayMs: { type: "integer", default: 5 },
      },
      required: ["points"],
    },
  },
  {
    name: "mouse_scroll",
    description: "Scroll the mouse wheel (positive = up, negative = down).",
    inputSchema: {
      type: "object",
      properties: {
        delta: { type: "integer", description: "Scroll notches (+ up, - down)." },
        x: { type: "number" },
        y: { type: "number" },
        coordSpace: { type: "string", enum: ["image", "screen"], default: "image" },
      },
      required: ["delta"],
    },
  },
  {
    name: "type_text",
    description:
      "Type text into the currently focused field. Automatically uses clipboard paste (with restore) for Cyrillic/Unicode/long text so keyboard layout never breaks it.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string" },
        useClipboard: { type: "boolean", description: "Force clipboard paste (true) or SendInput unicode (false)." },
        pressEnter: { type: "boolean", default: false },
      },
      required: ["text"],
    },
  },
  {
    name: "key_press",
    description:
      "Press a key or hotkey combo (e.g. 'enter', 'ctrl+c', 'ctrl+l', 'alt+tab', 'win+r'). Close combos like 'alt+f4' or 'ctrl+w' require allowClose: true.",
    inputSchema: {
      type: "object",
      properties: {
        keys: { type: "string" },
        allowClose: { type: "boolean", default: false },
      },
      required: ["keys"],
    },
  },
  {
    name: "list_windows",
    description: "List all visible top-level windows with titles, processes, handles, and positions.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "focus_window",
    description: "Bring a window to the foreground by titleContains, processName, or handle.",
    inputSchema: {
      type: "object",
      properties: {
        titleContains: { type: "string" },
        processName: { type: "string" },
        handle: { type: "integer" },
      },
    },
  },
  {
    name: "batch_actions",
    description:
      "SPEED TOOL: Execute a sequence of desktop actions in ONE turn without waiting for LLM round-trips between steps. Supports: click_element, type_into_element, click, move, drag, scroll, type, key, wait, focus_window, window_action, launch_app. Live-updates the overlay on every step and respects Ctrl+Alt+X abort immediately.",
    inputSchema: {
      type: "object",
      properties: {
        actions: { type: "array", items: { type: "object" } },
        hideOverlayAfter: {
          type: "boolean",
          default: false,
          description: "Automatically hide the screen border after the batch finishes.",
        },
      },
      required: ["actions"],
    },
  },
  {
    name: "zoom_region",
    description:
      "Crop and magnify a small area around (x, y) by 2.5x with an optional real-screen coordinate grid overlay. Ideal for reading tiny text, clicking small icons, or operating games/Canvas UIs. Updates image coordinate mapping so a subsequent mouse_click(x, y, coordSpace='image') on the zoomed image clicks the exact pixel on screen.",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number", description: "Center X coordinate (in image or screen space)." },
        y: { type: "number", description: "Center Y coordinate (in image or screen space)." },
        coordSpace: { type: "string", enum: ["image", "screen"], default: "image" },
        width: { type: "integer", default: 400, description: "Width of screen region to crop in physical pixels (default 400)." },
        height: { type: "integer", default: 300, description: "Height of screen region to crop in physical pixels (default 300)." },
        zoom: { type: "number", default: 2.5, description: "Magnification factor 1.0..4.0 (default 2.5)." },
        drawGrid: { type: "boolean", default: true, description: "Draw subtle coordinate grid with real screen X/Y labels." },
      },
      required: ["x", "y"],
    },
  },
];

async function handleToolCall(name, args = {}) {
  if (name === "set_overlay") {
    if (args.resetAbort) abortedByUser = false;
    if (args.visible) {
      overlay.show(args.status || "Активен");
    } else {
      overlay.hide();
    }
    return {
      content: [{ type: "text", text: JSON.stringify({ ok: true, visible: Boolean(args.visible), abortedByUser }) }],
    };
  }

  // Allow desktop_state / list_windows / get_screenshot to report abort cleanly, block mutating actions when aborted
  const isReadOnly = name === "desktop_state" || name === "get_screenshot" || name === "zoom_region" || name === "list_windows";
  if (!isReadOnly) {
    assertNotAborted();
  }

  switch (name) {
    case "desktop_state": {
      if (!abortedByUser) overlay.show("Снимаю скриншот и сканирую элементы интерфейса...");
      const res = await worker.call({
        action: "desktop_state",
        includeScreenshot: args.includeScreenshot !== false,
        annotated: args.annotated !== false,
        maxWidth: typeof args.maxWidth === "number" ? args.maxWidth : 1280,
        maxElements: typeof args.maxElements === "number" ? args.maxElements : 80,
        includeTaskbar: args.includeTaskbar !== false,
        monitor: args.monitor || "active",
      });

      lastScreenMeta = {
        originX: res.originX || 0,
        originY: res.originY || 0,
        screenWidth: res.screenWidth,
        screenHeight: res.screenHeight,
        imageWidth: res.imageWidth,
        imageHeight: res.imageHeight,
      };
      if (!abortedByUser) {
        const winTitle = res.activeWindow ? res.activeWindow.ProcessName : "Рабочий стол";
        const elCount = (res.elements || []).length;
        overlay.show(
          `Скриншот получен • ${winTitle} • найдено ${elCount} UI-элементов`,
          { x: lastScreenMeta.originX, y: lastScreenMeta.originY, width: lastScreenMeta.screenWidth, height: lastScreenMeta.screenHeight }
        );
      }

      const content = [];
      if (res.pngBase64) {
        content.push({ type: "image", data: res.pngBase64, mimeType: "image/png" });
      }

      const activeStr = res.activeWindow
        ? `"${res.activeWindow.Title}" (${res.activeWindow.ProcessName}, handle=${res.activeWindow.Handle})`
        : "(none)";
      const winList = (res.windows || [])
        .slice(0, 15)
        .map((w) => `${w.IsForeground ? "* " : "  "}"${w.Title}" (${w.ProcessName}, handle=${w.Handle}${w.IsMinimized ? ", minimized" : ""})`)
        .join("\n");

      const summary = [
        abortedByUser ? "WARNING: User pressed Ctrl+Alt+X abort hotkey. Ask before resuming actions.\n" : "",
        `Screen: ${res.screenWidth}x${res.screenHeight} (image: ${res.imageWidth}x${res.imageHeight}), Cursor: (${res.cursorX},${res.cursorY})`,
        `Active Window: ${activeStr}`,
        `\nOpen Windows (${(res.windows || []).length}):\n${winList || "  (none)"}`,
        `\nInteractive UI Elements (${(res.elements || []).length}${res.truncated ? ", truncated" : ""}):\n${formatElementsSummary(res.elements)}`,
      ]
        .filter(Boolean)
        .join("\n");

      content.push({ type: "text", text: summary });
      return { content };
    }

    case "click_element": {
      const elId = Number(args.elementId);
      const btn = args.button || "left";
      const clicks = args.clicks || 1;
      overlay.show(`Навожу курсор на элемент #${elId}...`);
      const res = await worker.call({
        action: "click_element",
        elementId: elId,
        button: btn,
        clicks,
        allowClose: Boolean(args.allowClose),
      });
      const fullName = res.name ? res.name.slice(0, 65) : `#${elId}`;
      const tagName = res.name ? res.name.slice(0, 26) : `#${elId}`;
      const clickWord = clicks === 2 ? "Двойной клик" : btn === "right" ? "ПКМ" : "Клик";
      overlay.click(res.x, res.y, btn, tagName, `${clickWord} (${res.type || "UI"}): ${fullName}`);
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "type_into_element": {
      const elId = Number(args.elementId);
      const text = String(args.text ?? "");
      const preview = text.length > 35 ? text.slice(0, 35) + "…" : text;
      overlay.show(`Ввод текста в поле #${elId}: «${preview}»`);
      const res = await worker.call({
        action: "type_into_element",
        elementId: elId,
        text,
        clearFirst: Boolean(args.clearFirst),
        pressEnter: Boolean(args.pressEnter),
        useClipboard: args.useClipboard !== false,
      });
      const fullName = res.name ? res.name.slice(0, 35) : `#${elId}`;
      overlay.click(res.x, res.y, "left", `Ввод текста`, `Введено в «${fullName}»: «${preview}»${args.pressEnter ? " + Enter" : ""}`);
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "launch_app": {
      const target = String(args.target ?? "");
      overlay.show(`Запускаю приложение: ${target}`);
      const res = await worker.call({
        action: "launch_app",
        target,
        args: args.args ? String(args.args) : "",
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "window_action": {
      const wa = String(args.windowAction || "focus").toLowerCase();
      if (wa === "close" && !args.confirmClose) {
        throw new Error("Refusing to close window without confirmClose: true. Only close windows if the user explicitly asked.");
      }
      const waNames = { focus: "Переключаюсь на окно", maximize: "Разворачиваю окно", minimize: "Сворачиваю окно", restore: "Восстанавливаю окно", move_resize: "Меняю размер окна", close: "Закрываю окно" };
      overlay.show(`${waNames[wa] || wa}: ${args.titleContains || args.processName || args.handle || ""}`);
      const res = await worker.call({
        action: "window_action",
        windowAction: wa,
        titleContains: args.titleContains,
        processName: args.processName,
        handle: args.handle,
        x: args.x,
        y: args.y,
        width: args.width,
        height: args.height,
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "clipboard": {
      const mode = String(args.mode || "get").toLowerCase();
      overlay.show(mode === "set" ? "Копирую в буфер обмена..." : "Читаю буфер обмена...");
      const res = await worker.call({ action: "clipboard", mode, text: args.text });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "wait": {
      const ms = Math.max(0, Math.min(15000, Number(args.ms ?? 500)));
      overlay.show(`Ожидание ${ms} мс...`);
      const res = await worker.call({ action: "sleep", ms });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "zoom_region": {
      const pos = mapCoords(args.x, args.y, args.coordSpace || "image");
      if (!pos) throw new Error("zoom_region requires numeric x and y");
      const w = typeof args.width === "number" ? args.width : 400;
      const h = typeof args.height === "number" ? args.height : 300;
      const zoom = typeof args.zoom === "number" ? args.zoom : 2.5;
      const drawGrid = args.drawGrid !== false;
      if (!abortedByUser) overlay.show(`Приближаю область ${w}×${h} (${zoom}×) вокруг (${pos.x}, ${pos.y})...`);
      const res = await worker.call({
        action: "zoom_region",
        x: pos.x,
        y: pos.y,
        width: w,
        height: h,
        zoom,
        drawGrid,
      });
      lastScreenMeta = {
        originX: res.originX || 0,
        originY: res.originY || 0,
        screenWidth: res.screenWidth,
        screenHeight: res.screenHeight,
        imageWidth: res.imageWidth,
        imageHeight: res.imageHeight,
      };
      return {
        content: [
          { type: "image", data: res.pngBase64, mimeType: "image/png" },
          {
            type: "text",
            text: JSON.stringify({
              ...lastScreenMeta,
              note: "You can click directly on this zoomed image using mouse_click(x, y, coordSpace='image') OR use the real screen grid coordinates with coordSpace='screen'.",
            }),
          },
        ],
      };
    }

    case "get_screenshot": {
      if (!abortedByUser) overlay.show("Снимаю скриншот...");
      const res = await worker.call({
        action: "screenshot",
        maxWidth: typeof args.maxWidth === "number" ? args.maxWidth : 1280,
        monitor: args.monitor || "active",
      });
      lastScreenMeta = {
        originX: res.originX || 0,
        originY: res.originY || 0,
        screenWidth: res.screenWidth,
        screenHeight: res.screenHeight,
        imageWidth: res.imageWidth,
        imageHeight: res.imageHeight,
      };
      if (!abortedByUser) {
        overlay.show("Скриншот получен", {
          x: lastScreenMeta.originX,
          y: lastScreenMeta.originY,
          width: lastScreenMeta.screenWidth,
          height: lastScreenMeta.screenHeight,
        });
      }
      return {
        content: [
          { type: "image", data: res.pngBase64, mimeType: "image/png" },
          { type: "text", text: JSON.stringify(lastScreenMeta) },
        ],
      };
    }

    case "mouse_click": {
      const pos =
        typeof args.x === "number" && typeof args.y === "number"
          ? mapCoords(args.x, args.y, args.coordSpace || "image")
          : null;
      const btn = args.button || "left";
      if (pos) overlay.click(pos.x, pos.y, btn, "Клик", `Клик (${pos.x}, ${pos.y})`);
      else overlay.show("Клик мышью...");
      const res = await worker.call({
        action: "mouse_click",
        ...(pos ? { x: pos.x, y: pos.y } : {}),
        button: btn,
        clicks: args.clicks || 1,
        smooth: args.smooth !== false,
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "mouse_move": {
      const pos = mapCoords(args.x, args.y, args.coordSpace || "image");
      if (!pos) throw new Error("mouse_move requires numeric x and y");
      overlay.cursor(pos.x, pos.y, "AI", `Навожу курсор (${pos.x}, ${pos.y})`);
      const res = await worker.call({
        action: "mouse_move",
        x: pos.x,
        y: pos.y,
        smooth: args.smooth !== false,
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "mouse_drag": {
      const p1 = mapCoords(args.x1, args.y1, args.coordSpace || "image");
      const p2 = mapCoords(args.x2, args.y2, args.coordSpace || "image");
      if (!p1 || !p2) throw new Error("mouse_drag requires numeric x1, y1, x2, y2");
      overlay.cursor(p1.x, p1.y, "Drag", `Перетаскиваю...`);
      const res = await worker.call({
        action: "mouse_drag",
        x1: p1.x,
        y1: p1.y,
        x2: p2.x,
        y2: p2.y,
        button: args.button || "left",
        steps: typeof args.steps === "number" ? args.steps : 20,
        durationMs: typeof args.durationMs === "number" ? args.durationMs : 180,
      });
      overlay.cursor(p2.x, p2.y, "AI", `Перетаскивание завершено`);
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "mouse_path": {
      const cs = args.coordSpace || "image";
      const pts = (args.points || []).map((pt) => mapCoords(pt.x, pt.y, cs)).filter(Boolean);
      overlay.show("Двигаю мышь по траектории...");
      const res = await worker.call({
        action: "mouse_path",
        points: pts,
        button: args.button || "left",
        holdButton: args.holdButton !== false,
        stepDelayMs: typeof args.stepDelayMs === "number" ? args.stepDelayMs : 5,
      });
      if (pts.length > 0) {
        const last = pts[pts.length - 1];
        overlay.cursor(last.x, last.y, "AI");
      }
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "mouse_scroll": {
      const pos =
        typeof args.x === "number" && typeof args.y === "number"
          ? mapCoords(args.x, args.y, args.coordSpace || "image")
          : null;
      const delta = Number(args.delta || 0);
      if (pos) overlay.cursor(pos.x, pos.y, "Scroll", delta > 0 ? "Прокрутка вверх" : "Прокрутка вниз");
      else overlay.show(delta > 0 ? "Прокрутка вверх" : "Прокрутка вниз");
      const res = await worker.call({
        action: "mouse_scroll",
        delta,
        ...(pos ? { x: pos.x, y: pos.y } : {}),
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "type_text": {
      const text = String(args.text ?? "");
      overlay.show(`Ввожу текст (${text.length} симв.)...`);
      const res = await worker.call({
        action: "type_text",
        text,
        ...(typeof args.useClipboard === "boolean" ? { useClipboard: args.useClipboard } : {}),
        pressEnter: Boolean(args.pressEnter),
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "key_press": {
      const keys = String(args.keys ?? "");
      if (isDangerousCloseCombo(keys) && !args.allowClose) {
        throw new Error(
          `Blocked potentially unintended close shortcut "${keys}". Only close apps if explicitly requested by the user, passing allowClose: true.`
        );
      }
      overlay.show(`Клавиши: ${keys}`);
      const res = await worker.call({ action: "key_press", keys });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "list_windows": {
      const res = await worker.call({ action: "list_windows" });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "focus_window": {
      overlay.show(`Переключаюсь на окно: ${args.titleContains || args.processName || args.handle || ""}`);
      const res = await worker.call({
        action: "focus_window",
        titleContains: args.titleContains,
        processName: args.processName,
        handle: args.handle,
      });
      return { content: [{ type: "text", text: JSON.stringify(res) }] };
    }

    case "batch_actions": {
      const rawActions = Array.isArray(args.actions) ? args.actions : (Array.isArray(args.Actions) ? args.Actions : []);
      if (rawActions.length === 0) {
        throw new Error("batch_actions requires a non-empty 'actions' array.");
      }
      const actions = rawActions.map(normalizeBatchItem);
      const total = actions.length;
      const results = [];

      for (let i = 0; i < total; i++) {
        assertNotAborted();
        const act = actions[i];
        const prefix = `[${i + 1}/${total}]`;

        switch (act.action) {
          case "click_element": {
            const res = await worker.call(act);
            const fullName = res.name ? res.name.slice(0, 55) : `#${act.elementId}`;
            const tagName = res.name ? res.name.slice(0, 24) : `#${act.elementId}`;
            overlay.click(res.x, res.y, act.button || "left", tagName, `${prefix} Клик: ${fullName}`);
            results.push(res);
            break;
          }
          case "type_into_element": {
            const preview = act.text.length > 30 ? act.text.slice(0, 30) + "…" : act.text;
            const res = await worker.call(act);
            const fullName = res.name ? res.name.slice(0, 30) : `#${act.elementId}`;
            overlay.click(res.x, res.y, "left", "Ввод текста", `${prefix} Ввод в «${fullName}»: «${preview}»`);
            results.push(res);
            break;
          }
          case "mouse_click": {
            if (typeof act.x === "number" && typeof act.y === "number") {
              overlay.click(act.x, act.y, act.button || "left", "Клик", `${prefix} Клик (${act.x}, ${act.y})`);
            } else {
              overlay.show(`${prefix} Клик мышью`);
            }
            results.push(await worker.call(act));
            break;
          }
          case "mouse_move": {
            overlay.cursor(act.x, act.y, "Наведение", `${prefix} Наведение (${act.x}, ${act.y})`);
            results.push(await worker.call(act));
            break;
          }
          case "mouse_drag": {
            overlay.cursor(act.x1, act.y1, "Перетаскивание", `${prefix} Перетаскивание`);
            results.push(await worker.call(act));
            overlay.cursor(act.x2, act.y2, "Готово", `${prefix} Перетаскивание завершено`);
            break;
          }
          case "mouse_scroll": {
            const dir = act.delta > 0 ? "вверх" : "вниз";
            if (typeof act.x === "number" && typeof act.y === "number") {
              overlay.cursor(act.x, act.y, `Прокрутка ${dir}`, `${prefix} Прокрутка ${dir}`);
            } else {
              overlay.show(`${prefix} Прокрутка ${dir}`);
            }
            results.push(await worker.call(act));
            break;
          }
          case "type_text": {
            const preview = act.text.length > 30 ? act.text.slice(0, 30) + "…" : act.text;
            overlay.show(`${prefix} Ввод текста: «${preview}»`);
            results.push(await worker.call(act));
            break;
          }
          case "key_press": {
            overlay.show(`${prefix} Клавиши: ${act.keys}`);
            results.push(await worker.call(act));
            break;
          }
          case "focus_window":
          case "window_action": {
            overlay.show(`${prefix} Окно: ${act.titleContains || act.processName || act.handle || ""}`);
            results.push(await worker.call(act));
            break;
          }
          case "launch_app": {
            overlay.show(`${prefix} Запуск: ${act.target}`);
            results.push(await worker.call(act));
            break;
          }
          case "sleep": {
            overlay.show(`${prefix} Пауза ${act.ms} мс`);
            results.push(await worker.call(act));
            break;
          }
          default: {
            results.push(await worker.call(act));
            break;
          }
        }
      }

      if (args.hideOverlayAfter) {
        overlay.hide();
      }
      return { content: [{ type: "text", text: JSON.stringify({ ok: true, count: results.length, results }) }] };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

async function handleMessage(msg) {
  if (!msg || typeof msg !== "object") return;
  const { id, method, params } = msg;

  if (id === undefined || id === null) {
    return;
  }

  try {
    if (method === "initialize") {
      send({
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: params?.protocolVersion || "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: { name: "windows-desktop-mcp", version: "3.0.0" },
        },
      });
      return;
    }

    if (method === "ping") {
      send({ jsonrpc: "2.0", id, result: {} });
      return;
    }

    if (method === "tools/list") {
      send({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
      return;
    }

    if (method === "tools/call") {
      const result = await handleToolCall(params?.name, params?.arguments);
      send({ jsonrpc: "2.0", id, result });
      return;
    }

    send({
      jsonrpc: "2.0",
      id,
      error: { code: -32601, message: `Method not found: ${method}` },
    });
  } catch (err) {
    send({
      jsonrpc: "2.0",
      id,
      result: {
        isError: true,
        content: [{ type: "text", text: String(err?.message || err) }],
      },
    });
  }
}

let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  let idx;
  while ((idx = buffer.indexOf("\n")) !== -1) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;
    try {
      const msg = JSON.parse(line);
      handleMessage(msg);
    } catch (e) {
      process.stderr.write(`Invalid JSON-RPC message: ${e.message}\n`);
    }
  }
});

function shutdown() {
  try {
    if (worker.proc) {
      try {
        if (worker.proc.stdin && !worker.proc.stdin.destroyed) worker.proc.stdin.end();
      } catch {}
      worker.proc.kill();
    }
  } catch {}
  overlay.kill();
}

process.stdin.on("end", () => {
  shutdown();
  process.exit(0);
});

process.on("SIGINT", () => {
  shutdown();
  process.exit(0);
});

process.on("SIGTERM", () => {
  shutdown();
  process.exit(0);
});

process.on("exit", shutdown);

process.stderr.write("windows-desktop-mcp v3.0.0 started\n");
