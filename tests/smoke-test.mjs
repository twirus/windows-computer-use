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

function rpc(method, params = {}) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`RPC timeout for ${method}`));
    }, 15000);
    pending.set(id, {
      resolve: (msg) => {
        clearTimeout(timer);
        resolve(msg);
      },
    });
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}

async function run() {
  const init = await rpc("initialize", { protocolVersion: "2024-11-05" });
  assert.equal(init.result.serverInfo.name, "windows-desktop-mcp");

  const list = await rpc("tools/list");
  const names = list.result.tools.map((t) => t.name);
  assert.equal(names.length, 20, `Expected 20 tools, got ${names.length}`);
  for (const required of ["desktop_state", "click_element", "type_into_element", "zoom_region", "batch_actions", "set_overlay"]) {
    assert.ok(names.includes(required), `Missing tool: ${required}`);
  }

  const blockF4 = await rpc("tools/call", { name: "key_press", arguments: { keys: "f4+alt" } });
  assert.equal(Boolean(blockF4.result.isError), true, "f4+alt must be blocked");

  const blockCtrlW = await rpc("tools/call", { name: "key_press", arguments: { keys: "w+ctrl" } });
  assert.equal(Boolean(blockCtrlW.result.isError), true, "w+ctrl must be blocked");

  const blockCloseWin = await rpc("tools/call", { name: "window_action", arguments: { windowAction: "close", processName: "notepad" } });
  assert.equal(Boolean(blockCloseWin.result.isError), true, "window_action(close) without confirmClose must be blocked");

  const emptyBatch = await rpc("tools/call", { name: "batch_actions", arguments: { actions: [] } });
  assert.equal(Boolean(emptyBatch.result.isError), true, "empty batch_actions must error");

  const validBatch = await rpc("tools/call", {
    name: "batch_actions",
    arguments: { actions: [{ type: "wait", ms: 40 }], hideOverlayAfter: true },
  });
  assert.equal(Boolean(validBatch.result.isError), false, "valid batch_actions must succeed");

  const state = await rpc("tools/call", { name: "desktop_state", arguments: { includeScreenshot: false } });
  assert.equal(Boolean(state.result.isError), false, "desktop_state(includeScreenshot=false) must succeed");

  const exitPromise = new Promise((resolve) => child.on("exit", resolve));
  child.stdin.end();
  const exitCode = await exitPromise;
  assert.equal(exitCode, 0, `Expected clean exit code 0, got ${exitCode}`);

  console.log("ALL SMOKE TESTS PASSED (8/8)");
}

run().catch((err) => {
  console.error("TEST FAILED:", err);
  try { child.kill(); } catch {}
  process.exit(1);
});
