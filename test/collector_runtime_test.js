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
    setTimeout: (fn) => {
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
      return Promise.resolve({ ok: status >= 200 && status < 300, status });
    },
    Promise,
    JSON,
    Date,
    URLSearchParams,
    console
  };
  vm.runInNewContext(source, context);
  return { listeners, posts, document };
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

  console.log("collector runtime assertions passed");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
