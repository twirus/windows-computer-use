import { spawn } from "node:child_process";
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVER_PATH = path.resolve(__dirname, "..", "src", "server.js");

const child = spawn("node", [SERVER_PATH], {
  stdio: ["pipe", "pipe", "pipe"],
});

let stdoutBuf = "";
const pending = new Map();
let nextId = 1;

child.stderr.on("data", (chunk) => {
  const s = chunk.toString("utf8").trim();
  if (s && !s.includes("started")) {
    console.error("[server stderr]", s);
  }
});

child.stdout.on("data", (chunk) => {
  stdoutBuf += chunk.toString("utf8");
  let idx;
  while ((idx = stdoutBuf.indexOf("\n")) !== -1) {
    const line = stdoutBuf.slice(0, idx).trim();
    stdoutBuf = stdoutBuf.slice(idx + 1);
    if (!line) continue;
    const msg = JSON.parse(line);
    if (msg.id && pending.has(msg.id)) {
      const { resolve } = pending.get(msg.id);
      pending.delete(msg.id);
      resolve(msg);
    }
  }
});

function rpc(method, params = {}, timeoutMs = 20000) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`RPC timeout for ${method}`));
    }, timeoutMs);
    pending.set(id, {
      resolve: (msg) => {
        clearTimeout(timer);
        resolve(msg);
      },
    });
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}

let passed = 0;
function ok(label) {
  passed++;
  console.log(`  [PASS] ${label}`);
}

async function run() {
  // 1. Protocol & discovery
  const init = await rpc("initialize", { protocolVersion: "2024-11-05" });
  assert.equal(init.result.serverInfo.name, "windows-desktop-mcp");
  ok("initialize");

  const ping = await rpc("ping");
  assert.deepEqual(ping.result, {});
  ok("ping");

  const unknownMethod = await rpc("nonexistent/method");
  assert.equal(unknownMethod.error?.code, -32601);
  ok("unknown RPC method -> -32601");

  const list = await rpc("tools/list");
  const tools = list.result.tools;
  const names = tools.map((t) => t.name);
  assert.equal(names.length, 21, `Expected 21 tools, got ${names.length}`);
  for (const required of ["desktop_state", "click_element", "type_into_element", "zoom_region", "batch_actions", "wait_for", "set_overlay"]) {
    assert.ok(names.includes(required), `Missing tool: ${required}`);
  }
  const dsTool = tools.find((t) => t.name === "desktop_state");
  const ssTool = tools.find((t) => t.name === "get_screenshot");
  const batchTool = tools.find((t) => t.name === "batch_actions");
  assert.ok(dsTool.inputSchema.properties.monitor, "desktop_state schema must expose monitor");
  assert.ok(dsTool.inputSchema.properties.scope, "desktop_state schema must expose scope");
  assert.ok(dsTool.inputSchema.properties.format, "desktop_state schema must expose format");
  assert.ok(ssTool.inputSchema.properties.monitor, "get_screenshot schema must expose monitor");
  assert.ok(batchTool.inputSchema.properties.returnStateAfter, "batch_actions schema must expose returnStateAfter");
  ok("tools/list (21 tools + v3.2 schemas)");

  // 2. Safety blocks (direct + batch)
  for (const combo of ["f4+alt", "w+ctrl", "control+q", "ctrl+shift+w", "menu+f4", "win+l", "l+lwin"]) {
    const res = await rpc("tools/call", { name: "key_press", arguments: { keys: combo } });
    assert.equal(Boolean(res.result.isError), true, `${combo} must be blocked`);
  }
  ok("dangerous close/lock key combos blocked");

  const batchCloseCombo = await rpc("tools/call", {
    name: "batch_actions",
    arguments: { actions: [{ type: "key", keys: "alt+f4" }] },
  });
  assert.equal(Boolean(batchCloseCombo.result.isError), true, "alt+f4 in batch must be blocked");

  const blockCloseWin = await rpc("tools/call", {
    name: "window_action",
    arguments: { windowAction: "close", processName: "notepad" },
  });
  assert.equal(Boolean(blockCloseWin.result.isError), true, "window_action(close) without confirmClose must be blocked");

  const batchCloseWin = await rpc("tools/call", {
    name: "batch_actions",
    arguments: { actions: [{ type: "window_action", windowAction: "close", processName: "notepad" }] },
  });
  assert.equal(Boolean(batchCloseWin.result.isError), true, "window_action(close) in batch without confirmClose must be blocked");
  ok("close window/hotkey guards (direct + batch)");

  // 3. Input validation edge cases
  const emptyFocus = await rpc("tools/call", { name: "focus_window", arguments: {} });
  assert.equal(Boolean(emptyFocus.result.isError), true, "focus_window without selector must error");

  const emptyLaunch = await rpc("tools/call", { name: "launch_app", arguments: { target: "   " } });
  assert.equal(Boolean(emptyLaunch.result.isError), true, "launch_app with empty target must error");

  const badMove = await rpc("tools/call", { name: "mouse_move", arguments: { x: "bad", y: 100 } });
  assert.equal(Boolean(badMove.result.isError), true, "mouse_move with non-numeric x must error");

  const badBatchEl = await rpc("tools/call", {
    name: "batch_actions",
    arguments: { actions: [{ type: "click_element" }] },
  });
  assert.equal(Boolean(badBatchEl.result.isError), true, "click_element without elementId in batch must error");

  const missingEl = await rpc("tools/call", { name: "click_element", arguments: { elementId: 99999 } });
  assert.equal(Boolean(missingEl.result.isError), true, "click_element #99999 must error");

  const emptyBatch = await rpc("tools/call", { name: "batch_actions", arguments: { actions: [] } });
  assert.equal(Boolean(emptyBatch.result.isError), true, "empty batch_actions must error");

  const emptyWaitFor = await rpc("tools/call", { name: "wait_for", arguments: {} });
  assert.equal(Boolean(emptyWaitFor.result.isError), true, "wait_for without criteria must error");

  const waitForMiss = await rpc("tools/call", {
    name: "wait_for",
    arguments: { windowTitleContains: "__nonexistent_window_title_xyz__", timeoutMs: 250, pollMs: 100 },
  });
  assert.equal(Boolean(waitForMiss.result.isError), false, "wait_for timeout should return matched=false cleanly");
  assert.equal(JSON.parse(waitForMiss.result.content[0].text).matched, false);

  const unknownTool = await rpc("tools/call", { name: "does_not_exist", arguments: {} });
  assert.equal(Boolean(unknownTool.result.isError), true, "unknown tool must error");
  ok("input validation, wait_for & error handling");

  // 4. Functional tests (non-disruptive)
  const wins = await rpc("tools/call", { name: "list_windows", arguments: {} });
  assert.equal(Boolean(wins.result.isError), false);
  const parsedWins = JSON.parse(wins.result.content[0].text);
  assert.ok(Array.isArray(parsedWins.windows), "list_windows should return a windows array");
  const hasInteractiveDesktop = parsedWins.windows.length > 0;
  ok(`list_windows (${parsedWins.windows.length} windows, interactive=${hasInteractiveDesktop})`);

  const stateTextOnly = await rpc("tools/call", { name: "desktop_state", arguments: { includeScreenshot: false } });
  assert.equal(Boolean(stateTextOnly.result.isError), false);
  ok("desktop_state (text only)");

  if (hasInteractiveDesktop) {
    const shotPrimary = await rpc("tools/call", {
      name: "get_screenshot",
      arguments: { monitor: "primary", maxWidth: 640 },
    });
    assert.equal(Boolean(shotPrimary.result.isError), false);
    assert.equal(shotPrimary.result.content[0].type, "image");
    const shotMeta = JSON.parse(shotPrimary.result.content[1].text);
    assert.equal(shotMeta.imageWidth, 640);
    ok("get_screenshot (primary, maxWidth=640)");

    const shotTinyClamp = await rpc("tools/call", {
      name: "get_screenshot",
      arguments: { monitor: "primary", maxWidth: 10 },
    });
    assert.equal(Boolean(shotTinyClamp.result.isError), false);
    const tinyMeta = JSON.parse(shotTinyClamp.result.content[1].text);
    assert.ok(tinyMeta.imageWidth >= 160, `Expected clamped width >= 160, got ${tinyMeta.imageWidth}`);
    ok("get_screenshot tiny maxWidth clamped safely");

    const zoomPos = await rpc("tools/call", {
      name: "zoom_region",
      arguments: { x: 400, y: 400, coordSpace: "screen", width: 240, height: 180, zoom: 2.0, drawGrid: true },
    });
    assert.equal(Boolean(zoomPos.result.isError), false);
    assert.equal(zoomPos.result.content[0].type, "image");
    ok("zoom_region (positive coords + grid)");

    const zoomNeg = await rpc("tools/call", {
      name: "zoom_region",
      arguments: { x: -200, y: 400, coordSpace: "screen", width: 240, height: 180, zoom: 2.0, drawGrid: true },
    });
    assert.equal(Boolean(zoomNeg.result.isError), false);
    assert.equal(zoomNeg.result.content[0].type, "image");
    ok("zoom_region (negative/clamped coords + grid)");

    // Clipboard round-trip with Cyrillic + Emoji + restore original
    const origClipRes = await rpc("tools/call", { name: "clipboard", arguments: { mode: "get" } });
    const origClip = JSON.parse(origClipRes.result.content[0].text).text || "";
    const testStr = "Проверка буфера Windows Computer Use 🤖⚡ 123";
    await rpc("tools/call", { name: "clipboard", arguments: { mode: "set", text: testStr } });
    const readBackRes = await rpc("tools/call", { name: "clipboard", arguments: { mode: "get" } });
    assert.equal(JSON.parse(readBackRes.result.content[0].text).text, testStr, "clipboard Cyrillic round-trip mismatch");
    await rpc("tools/call", { name: "clipboard", arguments: { mode: "set", text: origClip } });
    ok("clipboard Cyrillic/Unicode round-trip + restore");
  } else {
    console.log("  [SKIP] GDI screenshot/zoom/clipboard checks (non-interactive desktop session)");
  }

  // Batch with wait + invalid ms fallback + overlay hide
  const validBatch = await rpc("tools/call", {
    name: "batch_actions",
    arguments: { actions: [{ type: "wait", ms: 30 }, { type: "wait", ms: "not-a-number" }], hideOverlayAfter: true },
  });
  assert.equal(Boolean(validBatch.result.isError), false, "valid batch_actions must succeed");
  ok("batch_actions (wait + NaN guard + hideOverlayAfter)");

  // 5. Mini stress test: 14 consecutive desktop_state calls (crosses GC threshold of 12) + overlay show/hide
  const timings = [];
  for (let i = 0; i < 14; i++) {
    const t0 = Date.now();
    const st = await rpc("tools/call", {
      name: "desktop_state",
      arguments: { includeScreenshot: hasInteractiveDesktop, annotated: true, maxWidth: 800, maxElements: 40 },
    });
    assert.equal(Boolean(st.result.isError), false, `desktop_state #${i + 1} failed`);
    timings.push(Date.now() - t0);
  }
  const avgFirst5 = Math.round(timings.slice(0, 5).reduce((a, b) => a + b, 0) / 5);
  const avgLast5 = Math.round(timings.slice(-5).reduce((a, b) => a + b, 0) / 5);
  await rpc("tools/call", { name: "set_overlay", arguments: { visible: false } });
  ok(`stress test: 14x desktop_state (avg first 5: ${avgFirst5}ms, avg last 5: ${avgLast5}ms)`);

  // 6. Clean exit without orphan processes
  const exitPromise = new Promise((resolve) => child.on("exit", resolve));
  child.stdin.end();
  const exitCode = await exitPromise;
  assert.equal(exitCode, 0, `Expected clean exit code 0, got ${exitCode}`);
  ok("clean exit (code=0)");

  console.log(`\nALL TESTS PASSED (${passed}/${passed})`);
}

run().catch((err) => {
  console.error("TEST FAILED:", err);
  try { child.kill(); } catch {}
  process.exit(1);
});
