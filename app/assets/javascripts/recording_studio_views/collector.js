(function () {
  const CONTEXT_SELECTOR = "[data-recording-studio-views-context]";
  const RETRY_DELAYS = [0, 400, 1200];
  const RETRY_WINDOW_MS = 24 * 60 * 60 * 1000;
  let recordingThisTick = false;
  let turboAvailable = typeof window.Turbo !== "undefined";

  function contextPayload() {
    const el = document.querySelector(CONTEXT_SELECTOR);
    if (!el) return null;
    try {
      return JSON.parse(el.textContent);
    } catch (error) {
      return null;
    }
  }

  function csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : null;
  }

  function visible() {
    return document.visibilityState === "visible";
  }

  function turboPreview() {
    return document.documentElement.hasAttribute("data-turbo-preview");
  }

  function shouldDispatch() {
    if (!visible() || turboPreview()) return false;
    const payload = contextPayload();
    return !!(payload && payload.dispatch === true && payload.consent === true && payload.endpoint && payload.token);
  }

  function eventId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      return window.crypto.randomUUID();
    }
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (char) {
      const rand = (Math.random() * 16) | 0;
      const value = char === "x" ? rand : (rand & 0x3) | 0x8;
      return value.toString(16);
    });
  }

  function retryableStatus(status) {
    return status === 503 || status === 429 || status >= 500;
  }

  function postView(id, attempt) {
    const payload = contextPayload();
    if (!payload) return Promise.resolve();
    const body = JSON.stringify({
      event_id: id,
      token: payload.token,
      path: window.location.pathname
    });
    return fetch(payload.endpoint, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken() || "",
        Accept: "application/json"
      },
      body: body
    }).then(function (response) {
      if (response.ok || response.status === 204 || response.status === 409) return;
      if (retryableStatus(response.status) && attempt + 1 < RETRY_DELAYS.length) {
        return new Promise(function (resolve) {
          window.setTimeout(resolve, RETRY_DELAYS[attempt + 1]);
        }).then(function () {
          return postView(id, attempt + 1);
        });
      }
    }).catch(function () {
      if (attempt + 1 < RETRY_DELAYS.length) {
        return new Promise(function (resolve) {
          window.setTimeout(resolve, RETRY_DELAYS[attempt + 1]);
        }).then(function () {
          return postView(id, attempt + 1);
        });
      }
    });
  }

  function recordNavigation() {
    if (recordingThisTick) return;
    recordingThisTick = true;
    window.setTimeout(function () {
      recordingThisTick = false;
    }, 0);
    if (!shouldDispatch()) return;
    const id = eventId();
    const startedAt = Date.now();
    if (Date.now() - startedAt > RETRY_WINDOW_MS) return;
    postView(id, 0);
  }

  function onTurboLoad() {
    recordNavigation();
  }

  function onDomReady() {
    if (turboAvailable) return;
    recordNavigation();
  }

  function onPageShow(event) {
    if (event.persisted) recordNavigation();
  }

  document.addEventListener("turbo:load", onTurboLoad);
  document.addEventListener("DOMContentLoaded", onDomReady);
  window.addEventListener("pageshow", onPageShow);
  document.addEventListener("visibilitychange", function () {});
  window.addEventListener("hashchange", function () {});
})();
