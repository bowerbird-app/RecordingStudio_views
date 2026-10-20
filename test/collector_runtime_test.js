const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = fs.readFileSync(
  path.join(__dirname, "../app/assets/javascripts/recording_studio_views/collector.js"),
  "utf8"
);

function runCollector(options) {
  const posts = [];
  const timeouts = [];
  const consoleErrors = [];
  const scripts = options.scripts.map((text) => ({ textContent: text }));
  const listeners = {};
  const document = {
    visibilityState: options.visibilityState || "visible",
    documentElement: { hasAttribute: () => false },
    querySelectorAll: (selector) => (selector.includes("recording-studio-views-context") ? scripts : []),
    querySelector: (selector) => {
      if (selector === 'meta[name="csrf-token"]') return { getAttribute: () => "csrf" };
      return scripts[0] || null;
    },
    addEventListener: (name, fn) => {
      listeners[name] = listeners[name] || [];
      listeners[name].push(fn);
    }
  };
  const windowObj = {
    Turbo: options.turbo === false ? undefined : {},
    location: { pathname: options.pathname || "/pages/1", search: options.search || "" },
    crypto: { randomUUID: () => options.eventId || "11111111-1111-1111-1111-111111111111" },
    addEventListener: (name, fn) => {
      listeners[name] = listeners[name] || [];
      listeners[name].push(fn);
    },
    setTimeout: (fn, delay) => {
      timeouts.push(delay);
      fn();
      return 0;
    }
  };
  windowObj.window = windowObj;
  const context = {
    window: windowObj,
    document,
    fetch: (url, init) => {
      posts.push({ url, body: JSON.parse(init.body), token: JSON.parse(init.body).token });
      if (options.failNetwork && posts.length === 1) {
        return Promise.reject(new Error("network"));
      }
      const status = options.statusFor ? options.statusFor(posts.length) : 204;
      const retryAfter = options.retryAfterFor ? options.retryAfterFor(posts.length) : null;
      return Promise.resolve({
        ok: status >= 200 && status < 300,
        status,
        headers: {
          get: (name) => (String(name).toLowerCase() === "retry-after" ? retryAfter : null)
        }
      });
    },
    Promise,
    JSON,
    Date,
    Number,
    Math,
    URLSearchParams,
    console: {
      error: (...args) => consoleErrors.push(args),
      log: () => {}
    }
  };
  vm.runInNewContext(source, context);
  return { listeners, posts, document, timeouts, consoleErrors };
}

const first = JSON.stringify({
  dispatch: true,
  consent: true,
  endpoint: "/recording_studio_views/views",
  token: "token-one"
});
const second = JSON.stringify({
  dispatch: true,
  consent: true,
  endpoint: "/recording_studio_views/views",
  token: "token-two"
});

function flush() {
  return new Promise((resolve) => setImmediate(resolve));
}

async function main() {
  const turboVisit = runCollector({ scripts: [first, second], turbo: true });
  turboVisit.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  assert.strictEqual(turboVisit.posts.length, 1, "turbo visit posts once");
  assert.strictEqual(
    turboVisit.posts[0].token,
    "token-two",
    "uses the current page token, not the first head token"
  );

  const hidden = runCollector({ scripts: [second], visibilityState: "hidden", turbo: true });
  hidden.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  assert.strictEqual(hidden.posts.length, 0, "hidden tab does not post yet");
  hidden.document.visibilityState = "visible";
  hidden.listeners.visibilitychange.forEach((fn) => fn());
  await flush();
  assert.strictEqual(hidden.posts.length, 1, "activation posts exactly once");
  hidden.document.visibilityState = "hidden";
  hidden.listeners.visibilitychange.forEach((fn) => fn());
  hidden.document.visibilityState = "visible";
  hidden.listeners.visibilitychange.forEach((fn) => fn());
  await flush();
  assert.strictEqual(hidden.posts.length, 1, "later tab switches do not post again");

  const retry = runCollector({
    scripts: [second],
    turbo: true,
    failNetwork: true
  });
  retry.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  await flush();
  assert.ok(retry.posts.length >= 2, "retries after a failed post");
  const tokens = retry.posts.map((post) => post.token);
  assert.ok(tokens.every((token) => token === "token-two"), "retries reuse the captured token");

  const utm = runCollector({
    scripts: [second],
    turbo: true,
    pathname: "/pages/1",
    search: "?utm_source=google&utm_medium=cpc&utm_campaign=spring&other=1"
  });
  utm.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  assert.strictEqual(utm.posts[0].body.path, "/pages/1", "path stays pathname without query");
  assert.strictEqual(utm.posts[0].body.utm_source, "google");
  assert.strictEqual(utm.posts[0].body.utm_medium, "cpc");
  assert.strictEqual(utm.posts[0].body.utm_campaign, "spring");
  assert.strictEqual(utm.posts[0].body.other, undefined, "non-utm query keys are not sent");

  const throttled = runCollector({
    scripts: [second],
    turbo: true,
    statusFor: () => 429,
    retryAfterFor: () => "5"
  });
  throttled.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  await flush();
  assert.ok(throttled.timeouts.includes(5000), "429 waits Retry-After seconds before retry");
  assert.ok(throttled.posts.length >= 2, "429 retries after Retry-After");
  assert.strictEqual(throttled.consoleErrors.length, 0, "429 does not log console errors");

  const throttledNoHeader = runCollector({
    scripts: [second],
    turbo: true,
    statusFor: () => 429
  });
  throttledNoHeader.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  await flush();
  assert.strictEqual(throttledNoHeader.posts.length, 1, "429 without Retry-After does not retry");
  assert.ok(!throttledNoHeader.timeouts.includes(400), "429 does not use the immediate retry delay");
  assert.strictEqual(throttledNoHeader.consoleErrors.length, 0);

  const network = runCollector({
    scripts: [second],
    turbo: true,
    failNetwork: true
  });
  network.listeners["turbo:load"].forEach((fn) => fn());
  await flush();
  await flush();
  assert.ok(network.posts.length >= 2, "retries after a failed post");
  assert.strictEqual(network.consoleErrors.length, 0, "network errors stay silent");

  console.log("collector runtime assertions passed");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
