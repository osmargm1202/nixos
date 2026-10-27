import { recorder } from './session-record.mjs';

export default {
  id: 'orgm.tmux-session',
  tui: async (api) => {
    const record = recorder('opencode');
    let request;
    try { request = JSON.parse(process.env.ORGM_TMUX_RESUME_REQUEST || 'null'); } catch {}
    delete process.env.ORGM_TMUX_RESUME_REQUEST;
    let submitted = false;
    let previous;
    const update = () => {
      const route = api.route.current;
      const id = route.name === 'session' ? route.params?.sessionID : null;
      const cwd = api.state.path.directory || process.cwd();
      const key = JSON.stringify([id, cwd]);
      if (key !== previous) {
        previous = key;
        record({ id, cwd });
      }
      // --prompt is auto-submitted on the home route, not the resumed-session
      // route in OpenCode 1.4.3. Address the restored conversation explicitly.
      if (submitted || !request || !api.state.ready || id !== request.id) return;
      submitted = true;
      const body = { sessionID: id, parts: [{ type: 'text', text: request.prompt }] };
      if (request.agent) body.agent = request.agent;
      if (request.model?.includes('/')) {
        const [providerID, ...modelID] = request.model.split('/');
        body.model = { providerID, modelID: modelID.join('/') };
      }
      void api.client.session.promptAsync(body).catch(() => {});
    };
    update();
    const timer = setInterval(update, 250);
    timer.unref?.();
    api.lifecycle.onDispose(() => clearInterval(timer));
  },
};
