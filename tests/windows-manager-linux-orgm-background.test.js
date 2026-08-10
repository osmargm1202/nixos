#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { TextEncoder } = require("node:util");
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
    tabGets: [],
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
      async get(tabId) {
        calls.tabGets.push(tabId);
        const tab = tabs.find((candidate) => candidate.id === tabId);
        if (!tab) {
          throw new Error(`No tab with id: ${tabId}`);
        }
        return tab;
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

  vm.runInNewContext(source, { URL, TextEncoder, browser, setTimeout() {} }, { filename: backgroundPath });
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

  const listed = createHarness([
    {
      id: 71,
      windowId: 16,
      index: 3,
      active: false,
      title: "Example tab",
      url: "https://example.com/path",
      favIconUrl: "https://example.com/favicon.ico",
    },
    {
      id: 72,
      windowId: 17,
      index: 0,
      active: true,
      title: "",
      url: "about:blank",
      favIconUrl: "",
    },
  ]);
  await listed.deliver({ id: "list-tabs", type: "tab-operation", action: "list-tabs" });
  assert.equal(listed.calls.queried, 1);
  assert.deepEqual(listed.posted, [{
    id: "list-tabs",
    ok: true,
    tabs: [
      {
        id: 71,
        windowId: 16,
        index: 3,
        active: false,
        title: "Example tab",
        url: "https://example.com/path",
        favIconUrl: "https://example.com/favicon.ico",
      },
      {
        id: 72,
        windowId: 17,
        index: 0,
        active: true,
        url: "about:blank",
      },
    ],
  }]);

  const activated = createHarness([
    { id: 81, windowId: 18, index: 0, active: false },
    { id: 82, windowId: 19, index: 1, active: true },
  ]);
  await activated.deliver({
    id: "activate-tab",
    type: "tab-operation",
    action: "activate-tab",
    tabId: 81,
  });
  assert.deepEqual(activated.calls.tabGets, [81]);
  assert.deepEqual(activated.calls.windowUpdates, [{ details: { focused: true }, windowId: 18 }]);
  assert.deepEqual(activated.calls.tabUpdates, [{ details: { active: true }, tabId: 81 }]);
  assert.deepEqual(activated.calls.created, []);
  assert.deepEqual(activated.posted, [{ id: "activate-tab", ok: true, action: "activated" }]);

  await activated.deliver({
    id: "invalid-tab-id",
    type: "tab-operation",
    action: "activate-tab",
    tabId: true,
  });
  assert.deepEqual(activated.posted.at(-1), {
    id: "invalid-tab-id",
    ok: false,
    error: "tabId must be a positive integer",
  });

  await matching.deliver({
    id: "malformed-focus",
    type: "focus-existing",
    url: "https://netflix.com/",
    unexpected: true,
  });
  assert.deepEqual(matching.posted.at(-1), {
    id: "malformed-focus",
    ok: false,
    error: "Invalid native message",
  });

  const ordered = createHarness([
    { id: 91, windowId: 21, index: 0, active: true },
    { id: 92, windowId: 20, index: 5, active: false },
    { id: 93, windowId: 20, index: 1, active: false },
  ]);
  await ordered.deliver({ id: "ordered-tabs", type: "tab-operation", action: "list-tabs" });
  assert.deepEqual(ordered.posted[0].tabs.map((tab) => tab.id), [93, 92, 91]);

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
