const hostName = "windows_manager_linux_orgm";
let nativePort;

function httpOrigin(rawUrl) {
  const url = new URL(rawUrl);
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("Only HTTP(S) URLs are supported");
  }
  return url.origin;
}

async function focusExisting(url) {
  const requestedOrigin = httpOrigin(url);
  const tabs = await browser.tabs.query({});
  const existing = tabs.find((tab) => {
    try {
      return httpOrigin(tab.url) === requestedOrigin;
    } catch {
      return false;
    }
  });

  if (!existing) {
    throw new Error("No matching HTTP(S) tab found");
  }

  await browser.windows.update(existing.windowId, { focused: true });
  await browser.tabs.update(existing.id, { active: true });
  return "focused";
}

function connectNativeHost() {
  nativePort = browser.runtime.connectNative(hostName);
  nativePort.onMessage.addListener(async (message) => {
    try {
      if (message.type !== "focus-existing" || typeof message.id !== "string" || typeof message.url !== "string") {
        throw new Error("Invalid native message");
      }
      nativePort.postMessage({
        id: message.id,
        ok: true,
        action: await focusExisting(message.url),
      });
    } catch (error) {
      nativePort.postMessage({
        id: message.id,
        ok: false,
        error: error.message,
      });
    }
  });
  nativePort.onDisconnect.addListener(() => {
    nativePort = undefined;
    setTimeout(connectNativeHost, 1000);
  });
}

connectNativeHost();
