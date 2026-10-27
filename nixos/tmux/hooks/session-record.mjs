import fs from 'node:fs';
import path from 'node:path';

// One record per live process, never a directory-wide "last conversation".
export function recorder(tool) {
  if (!process.env.TMUX || !process.env.TMUX_PANE) return () => {};
  const runtime = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
  const directory = path.join(runtime, 'orgm-tmux-agents');
  const file = path.join(directory, `${process.pid}.json`);
  const stat = fs.readFileSync('/proc/self/stat', 'utf8');
  const start = stat.slice(stat.lastIndexOf(')') + 1).trim().split(/\s+/)[19];
  return (session) => {
    try {
      fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
      const data = { ...session, tool, pid: process.pid, start,
        tmux: process.env.TMUX, pane: process.env.TMUX_PANE };
      fs.writeFileSync(`${file}.tmp`, JSON.stringify(data), { mode: 0o600 });
      fs.renameSync(`${file}.tmp`, file);
    } catch {
      // Persistence must never interrupt the client's conversation.
    }
  };
}
