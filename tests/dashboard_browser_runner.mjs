import {spawn} from "node:child_process";
import {readFile, writeFile} from "node:fs/promises";
import {join} from "node:path";

const options = {};
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index];
  const value = process.argv[index + 1];
  if (!key?.startsWith("--") || value === undefined) throw new Error(`invalid argument: ${key || "(missing)"}`);
  options[key.slice(2)] = value;
}

for (const key of ["chrome", "url", "width", "height", "screenshot", "result", "profile"]) {
  if (!options[key]) throw new Error(`missing --${key}`);
}

const width = Number(options.width);
const height = Number(options.height);
if (!Number.isInteger(width) || !Number.isInteger(height) || width < 320 || height < 480) {
  throw new Error("invalid browser viewport");
}

const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

class DevToolsClient {
  constructor(url) {
    this.url = url;
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
  }

  async connect() {
    this.socket = new WebSocket(this.url);
    await new Promise((resolve, reject) => {
      this.socket.addEventListener("open", resolve, {once: true});
      this.socket.addEventListener("error", reject, {once: true});
    });
    this.socket.addEventListener("message", event => {
      const message = JSON.parse(String(event.data));
      if (message.id) {
        const pending = this.pending.get(message.id);
        if (!pending) return;
        this.pending.delete(message.id);
        message.error ? pending.reject(new Error(message.error.message)) : pending.resolve(message.result);
        return;
      }
      for (const listener of this.listeners.get(message.method) || []) listener(message.params || {});
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`timed out waiting for ${method}`));
      }, 30000);
      this.pending.set(id, {
        resolve: value => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: error => {
          clearTimeout(timer);
          reject(error);
        }
      });
      this.socket.send(JSON.stringify({id, method, params}));
    });
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) || [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }

  waitFor(method, timeoutMs) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`timed out waiting for ${method}`)), timeoutMs);
      this.on(method, params => {
        clearTimeout(timer);
        resolve(params);
      });
    });
  }

  close() {
    this.socket?.close();
  }
}

const chrome = spawn(options.chrome, [
  "--headless=new",
  "--disable-gpu",
  "--no-sandbox",
  "--hide-scrollbars",
  "--no-first-run",
  "--disable-default-apps",
  "--disable-component-update",
  "--remote-debugging-port=0",
  `--user-data-dir=${options.profile}`,
  "about:blank"
], {stdio: ["ignore", "ignore", "pipe"]});

let chromeErrors = "";
chrome.stderr.setEncoding("utf8");
chrome.stderr.on("data", chunk => { chromeErrors += chunk; });

let client;
try {
  const portFile = join(options.profile, "DevToolsActivePort");
  let port;
  for (let attempt = 0; attempt < 200; attempt += 1) {
    try {
      const lines = (await readFile(portFile, "utf8")).trim().split(/\r?\n/);
      port = Number(lines[0]);
      if (port) break;
    } catch {
      // Chrome has not opened the DevTools endpoint yet.
    }
    if (chrome.exitCode !== null) throw new Error(`Chrome exited before DevTools startup: ${chromeErrors}`);
    await delay(50);
  }
  if (!port) throw new Error("Chrome DevTools port did not become available");

  let targets;
  for (let attempt = 0; attempt < 100; attempt += 1) {
    try {
      targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      if (targets.some(target => target.type === "page")) break;
    } catch {
      // DevTools HTTP endpoint is still starting.
    }
    await delay(50);
  }
  const page = targets?.find(target => target.type === "page");
  if (!page?.webSocketDebuggerUrl) throw new Error("Chrome page target missing");

  client = new DevToolsClient(page.webSocketDebuggerUrl);
  await client.connect();
  const exceptions = [];
  client.on("Runtime.exceptionThrown", params => {
    const details = params.exceptionDetails || {};
    const description = details.exception?.description || details.text || "browser exception";
    const frames = (details.stackTrace?.callFrames || []).slice(0, 5).map(frame => `${frame.functionName || "(anonymous)"}@${frame.url}:${frame.lineNumber + 1}`);
    exceptions.push(frames.length ? `${description}\n${frames.join("\n")}` : description);
  });
  await client.send("Page.enable");
  await client.send("Runtime.enable");
  await client.send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width < 620
  });

  const loaded = client.waitFor("Page.loadEventFired", 30000);
  await client.send("Page.navigate", {url: options.url});
  await loaded;

  let encoded = "";
  for (let attempt = 0; attempt < 300; attempt += 1) {
    const evaluation = await client.send("Runtime.evaluate", {
      expression: "document.documentElement.dataset.aiopsVisualResult || ''",
      returnByValue: true
    });
    encoded = evaluation.result?.value || "";
    if (encoded) {
      const current = JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
      if (current.status !== "waiting") break;
    }
    await delay(100);
  }
  if (!encoded) throw new Error("dashboard visual probe did not publish a result");

  const result = JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
  result.browser_exceptions = exceptions;
  const layout = await client.send("Page.getLayoutMetrics");
  const contentSize = layout.cssContentSize || layout.contentSize;
  const screenshotWidth = Math.ceil(contentSize.width);
  const screenshotHeight = Math.ceil(contentSize.height);
  result.screenshot_mode = "full_page";
  result.screenshot_expected_width = screenshotWidth;
  result.screenshot_expected_height = screenshotHeight;
  result.viewport_width = width;
  result.viewport_height = height;
  const screenshot = await client.send("Page.captureScreenshot", {
    format: "png",
    captureBeyondViewport: true,
    fromSurface: true,
    clip: {x: 0, y: 0, width: screenshotWidth, height: screenshotHeight, scale: 1}
  });
  await writeFile(options.screenshot, Buffer.from(screenshot.data, "base64"));
  await writeFile(options.result, `${JSON.stringify(result, null, 2)}\n`);
} finally {
  try {
    if (client) await Promise.race([client.send("Browser.close"), delay(2000)]);
  } catch {
    // Chrome may already be shutting down.
  }
  client?.close();
  if (chrome.exitCode === null) chrome.kill("SIGTERM");
  await Promise.race([
    new Promise(resolve => chrome.once("exit", resolve)),
    delay(2000)
  ]);
  if (chrome.exitCode === null) chrome.kill("SIGKILL");
}

process.exit(0);
