const hostName = "windows_manager_linux_orgm";
let nativePort;

function normalizeUrl(rawUrl) {
  const url = new URL(rawUrl);
  url.hash = "";
  return url.href;
}

async function focusOrCreate(url) {
  const normalizedUrl = normalizeUrl(url);
  const tabs = await browser.tabs.query({});
  const existing = tabs.find((tab) => {
    try {
      return normalizeUrl(tab.url) === normalizedUrl;
    } catch {
      return false;
    }
  });

  if (existing) {
    await browser.windows.update(existing.windowId, { focused: true });
    await browser.tabs.update(existing.id, { active: true });
    return "focused";
  }

  const window = await browser.windows.getLastFocused();
  await browser.tabs.create({
    windowId: window.id,
    url: normalizedUrl,
    active: true,
  });
  return "created";
}

function connectNativeHost() {
  nativePort = browser.runtime.connectNative(hostName);
  nativePort.onMessage.addListener(async (message) => {
    try {
      if (message.type !== "focus-or-create" || typeof message.id !== "string" || typeof message.url !== "string") {
        throw new Error("Invalid native message");
      }
      nativePort.postMessage({
        id: message.id,
        ok: true,
        action: await focusOrCreate(message.url),
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
