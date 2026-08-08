#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const backgroundPath = path.resolve(
  __dirname,
  "../nixos/packages/windows-manager-linux-orgm/background.js",
);
const source = fs.readFileSync(backgroundPath, "utf8");

assert(!/\btabs\.create\b/.test(source), "background must not create tabs");
assert(!/\btabs\.onUpdated\b/.test(source), "background must not observe tab updates");
assert(!/\btab\.title\b/.test(source), "background must not identify tabs by title");

function cloneMessage(value) {
  return JSON.parse(JSON.stringify(value));
}

function createHarness(tabs) {
  const calls = {
    created: [],
    queried: 0,
    tabUpdates: [],
    windowUpdates: [],
  };
  const posted = [];
  let messageHandler;

  const browser = {
    runtime: {
      connectNative(hostName) {
        assert.equal(hostName, "windows_manager_linux_orgm");
        return {
          onDisconnect: { addListener() {} },
          onMessage: {
            addListener(handler) {
              messageHandler = handler;
            },
          },
          postMessage(message) {
            posted.push(cloneMessage(message));
          },
        };
      },
    },
    tabs: {
      async create(details) {
        calls.created.push(cloneMessage(details));
      },
      async query() {
        calls.queried += 1;
        return tabs;
      },
      async update(tabId, details) {
        calls.tabUpdates.push({ details: cloneMessage(details), tabId });
      },
    },
    windows: {
      async update(windowId, details) {
        calls.windowUpdates.push({ details: cloneMessage(details), windowId });
      },
    },
  };

  vm.runInNewContext(source, { URL, browser, setTimeout() {} }, { filename: backgroundPath });
  assert(messageHandler, "background must register a native message handler");

  return {
    calls,
    posted,
    async deliver(message) {
      await messageHandler(message);
    },
  };
}

async function main() {
  const matching = createHarness([
    {
      id: 41,
      title: "A title unrelated to the requested URL",
      url: "https://www.netflix.com/do-en/",
      windowId: 8,
    },
    {
      id: 42,
      url: "https://other.example.test/",
      windowId: 9,
    },
  ]);
  await matching.deliver({
    id: "focus-www-redirect",
    type: "focus-existing",
    url: "https://netflix.com/",
  });
  assert.deepEqual(matching.calls.windowUpdates, [{ details: { focused: true }, windowId: 8 }]);
  assert.deepEqual(matching.calls.tabUpdates, [{ details: { active: true }, tabId: 41 }]);
  assert.deepEqual(matching.calls.created, []);
  assert.deepEqual(matching.posted, [{ action: "focused", id: "focus-www-redirect", ok: true }]);

  const ownSubdomain = createHarness([
    { id: 61, url: "https://cloud.or-gm.com/index.php/apps/files/", windowId: 14 },
    { id: 62, url: "https://chat.or-gm.com/", windowId: 15 },
  ]);
  await ownSubdomain.deliver({
    id: "focus-own-subdomain",
    type: "focus-existing",
    url: "https://cloud.or-gm.com/index.php/apps/calendar/",
  });
  assert.deepEqual(ownSubdomain.calls.windowUpdates, [{ details: { focused: true }, windowId: 14 }]);
  assert.deepEqual(ownSubdomain.calls.tabUpdates, [{ details: { active: true }, tabId: 61 }]);
  assert.deepEqual(ownSubdomain.posted, [{ action: "focused", id: "focus-own-subdomain", ok: true }]);

  const noMatch = createHarness([
    { id: 51, url: "https://m.webapp.example.test/same-site-different-subdomain", windowId: 10 },
    { id: 52, url: "about:blank", windowId: 11 },
    { id: 53, url: "file:///tmp/webapp.html", windowId: 12 },
    { id: 54, url: "not a valid URL", windowId: 13 },
  ]);
  await noMatch.deliver({
    id: "no-match",
    type: "focus-existing",
    url: "https://webapp.example.test/requested/path?query=value#hash",
  });
  assert.equal(noMatch.calls.queried, 1);
  assert.deepEqual(noMatch.calls.windowUpdates, []);
  assert.deepEqual(noMatch.calls.tabUpdates, []);
  assert.deepEqual(noMatch.calls.created, []);
  assert.deepEqual(noMatch.posted, [
    { error: "No matching HTTP(S) tab found", id: "no-match", ok: false },
  ]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
