import { recorder } from './session-record.mjs';

export default function tmuxSession(pi) {
  const record = recorder(process.env.ORGM_TMUX_AGENT_TOOL);
  const update = (_event, ctx) => {
    // OMP extensions can also observe subagent contexts in this process.
    if (ctx.hasUI === false || ctx.agent?.kind === 'sub') return;
    record({ id: ctx.sessionManager.getSessionId(),
      sessionFile: ctx.sessionManager.getSessionFile(),
      cwd: ctx.sessionManager.getCwd?.() || ctx.cwd || process.cwd() });
  };
  for (const event of ['session_start', 'session_switch', 'session_branch', 'session_fork', 'session_tree']) {
    pi.on(event, update);
  }
}
