#!/usr/bin/env node
// Browser QA for destination branches. Requires Chrome remote debugging on 9230.

import fs from "node:fs/promises";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const tabs = await fetch("http://127.0.0.1:9230/json").then((response) => response.json());
const tab = tabs.find((item) => item.type === "page" && item.url.includes("127.0.0.1:5173"));
if (!tab) throw new Error("Story Atlas page not found");

const socket = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

let sequence = 0;
const waiting = new Map();
socket.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (!message.id || !waiting.has(message.id)) return;
  const { resolve, reject } = waiting.get(message.id);
  waiting.delete(message.id);
  if (message.error) reject(new Error(message.error.message));
  else resolve(message.result);
});

function send(method, params = {}) {
  const id = ++sequence;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => waiting.set(id, { resolve, reject }));
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const evaluate = (expression) => send("Runtime.evaluate", {
  expression,
  awaitPromise: true,
  returnByValue: true,
});
const clickText = async (text) => {
  const result = await evaluate(`(() => {
    const item = [...document.querySelectorAll("button")].find((button) => button.textContent.trim() === ${JSON.stringify(text)});
    if (!item) return false;
    item.click();
    return true;
  })()`);
  if (!result.result.value) throw new Error(`button not found: ${text}`);
  await sleep(350);
};
const screenshot = async (name) => {
  const result = await send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  const target = path.join(root, "docs", name);
  await fs.writeFile(target, Buffer.from(result.data, "base64"));
  return target;
};

await send("Runtime.enable");
await send("Page.enable");
await sleep(800);
await clickText("故事实例视图");
await clickText("含玩法");
await clickText("海边");
const branchText = (await evaluate("document.body.innerText")).result.value;
if (!branchText.includes("DEST-COAST") || !branchText.includes("海上日出") || !branchText.includes("海上日落")) {
  throw new Error("coast branch nodes not visible");
}
await evaluate(`document.querySelector(".react-flow__controls-fitview")?.click()`);
await sleep(500);
const branchShot = await screenshot("qa_story_atlas_coast_branch.png");

await clickText("场景布局视图");
await clickText("海边");
const layoutText = (await evaluate("document.body.innerText")).result.value;
if (!layoutText.includes("海边场景布局") || !layoutText.includes("6 个构成组")) {
  throw new Error("coast scene layout not visible");
}
const layoutShot = await screenshot("qa_story_atlas_coast_layout.png");

console.log(`PASS branch=${branchShot}`);
console.log(`PASS layout=${layoutShot}`);
socket.close();
