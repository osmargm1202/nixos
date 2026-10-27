import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import piExtension from '../nixos/tmux/hooks/pi-session.mjs';
import opencodePlugin from '../nixos/tmux/hooks/opencode-session.mjs';

const runtime = fs.mkdtempSync(path.join(os.tmpdir(), 'tmux-hooks-'));
Object.assign(process.env, { XDG_RUNTIME_DIR: runtime, TMUX: '/test/socket,1,0', TMUX_PANE: '%1' });
const file = path.join(runtime, 'orgm-tmux-agents', `${process.pid}.json`);
const read = () => JSON.parse(fs.readFileSync(file, 'utf8'));
try {
  for (const tool of ['pi', 'omp']) {
    process.env.ORGM_TMUX_AGENT_TOOL = tool;
    const handlers = new Map();
    piExtension({ on: (event, callback) => handlers.set(event, callback) });
    let id = '12345678-1234-1234-1234-123456789abc';
    const ctx = { hasUI: true, sessionManager: {
      getSessionId: () => id, getSessionFile: () => `/project with spaces/${id}.jsonl`,
      getCwd: () => '/project with spaces',
    } };
    handlers.get('session_start')({}, ctx);
    assert.equal(read().tool, tool);
    assert.equal(read().id, id);
    assert.equal(read().pid, process.pid);
    assert.equal(read().pane, '%1');
    id = '12345678-1234-1234-1234-123456789abd';
    handlers.get('session_switch')({}, ctx);
    assert.equal(read().id, id);
    handlers.get('session_start')({}, { ...ctx, hasUI: false, sessionManager: {
      getSessionId: () => 'subagent',
    } });
    assert.equal(read().id, id, 'subagent must not replace the foreground session');
    handlers.get('session_start')({}, { ...ctx, hasUI: true, agent: { kind: 'sub' },
      sessionManager: { getSessionId: () => 'focused-subagent' } });
    assert.equal(read().id, id, 'a focused OMP subagent must not replace the parent session');
  }
  let dispose;
  const submissions = [];
  process.env.ORGM_TMUX_RESUME_REQUEST = JSON.stringify({ id: 'ses_first', prompt: 'continue exactly this task',
    model: 'provider/model', agent: 'build' });
  const api = { route: { current: { name: 'session', params: { sessionID: 'ses_first' } } },
    state: { ready: false, path: { directory: '/project with spaces' } },
    client: { session: { promptAsync: async (body) => { submissions.push(body); } } },
    lifecycle: { onDispose: (callback) => { dispose = callback; } } };
  await opencodePlugin.tui(api);
  try {
    assert.equal(read().id, 'ses_first');
    assert.equal(submissions.length, 0, 'wait until the resumed interface is ready');
    api.state.ready = true;
    await new Promise(resolve => setTimeout(resolve, 300));
    assert.deepEqual(submissions, [{ sessionID: 'ses_first',
      parts: [{ type: 'text', text: 'continue exactly this task' }],
      model: { providerID: 'provider', modelID: 'model' }, agent: 'build' }]);
    api.route.current = { name: 'session', params: { sessionID: 'ses_other' } };
    await new Promise(resolve => setTimeout(resolve, 300));
    assert.equal(read().id, 'ses_other');
    api.route.current = { name: 'home' };
    await new Promise(resolve => setTimeout(resolve, 300));
    assert.equal(read().id, null, 'home screen must not retain the previous session');
    assert.equal(submissions.length, 1, 'restoration must submit exactly one continuation');
  } finally { dispose(); }
  console.log('PASS: Pi/OMP lifecycle changes, subagent exclusion, OpenCode TUI selection and home invalidation');
} finally { fs.rmSync(runtime, { recursive: true, force: true }); }
