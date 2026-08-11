const hostName = "windows_manager_linux_orgm";
let nativePort;
const maxNativeMessageBytes = 64 * 1024;

function postNativeMessage(message) {
  if (new TextEncoder().encode(JSON.stringify(message)).byteLength > maxNativeMessageBytes) {
    throw new Error("Native tab-list response exceeds maximum size");
  }
  nativePort.postMessage(message);
}


function webAppHost(rawUrl) {
  const url = new URL(rawUrl);
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new Error("Only HTTP(S) URLs are supported");
  }
  return url.hostname.toLowerCase().replace(/^www\./, "");
}

const maxFaviconUrlLength = 2048;

function cacheableFaviconUrl(value) {
  if (typeof value !== "string" || value === "" || value.length > maxFaviconUrlLength) {
    return undefined;
  }
  try {
    return new URL(value).protocol === "https:" ? value : undefined;
  } catch {
    return undefined;
  }
}

function tabDescriptor(tab) {
  const descriptor = {
    id: tab.id,
    windowId: tab.windowId,
    index: tab.index,
    active: tab.active,
  };

  for (const field of ["title", "url"]) {
    if (typeof tab[field] === "string" && tab[field] !== "") {
      descriptor[field] = tab[field];
    }
  }
  const favIconUrl = cacheableFaviconUrl(tab.favIconUrl);
  if (favIconUrl !== undefined) {
    descriptor.favIconUrl = favIconUrl;
  }

  return descriptor;
}

async function listTabs() {
  const tabs = await browser.tabs.query({});
  return tabs
    .map(tabDescriptor)
    .sort((left, right) => left.windowId - right.windowId || left.index - right.index);
}

async function activateTab(tabId) {
  if (!Number.isSafeInteger(tabId) || tabId <= 0) {
    throw new Error("tabId must be a positive integer");
  }

  const tab = await browser.tabs.get(tabId);
  await browser.windows.update(tab.windowId, { focused: true });
  await browser.tabs.update(tab.id, { active: true });
  return "activated";
}

async function focusExisting(url) {
  const requestedHost = webAppHost(url);
  const tabs = await browser.tabs.query({});
  const existing = tabs.find((tab) => {
    try {
      return webAppHost(tab.url) === requestedHost;
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
    const id = message && typeof message.id === "string" ? message.id : undefined;
    try {
      if (message?.type === "focus-existing") {
        if (
          typeof id !== "string"
          || typeof message.url !== "string"
          || Object.keys(message).length !== 3
        ) {
          throw new Error("Invalid native message");
        }
        postNativeMessage({
          id,
          ok: true,
          action: await focusExisting(message.url),
        });
        return;
      }

      if (message?.type !== "tab-operation" || typeof id !== "string") {
        throw new Error("Invalid native message");
      }

      if (message.action === "list-tabs" && Object.keys(message).length === 3) {
        postNativeMessage({
          id,
          ok: true,
          tabs: await listTabs(),
        });
        return;
      }

      if (
        message.action === "activate-tab"
        && Object.keys(message).length === 4
        && Object.hasOwn(message, "tabId")
      ) {
        postNativeMessage({
          id,
          ok: true,
          action: await activateTab(message.tabId),
        });
        return;
      }

      throw new Error("Invalid native message");
    } catch (error) {
      nativePort.postMessage({
        id,
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
