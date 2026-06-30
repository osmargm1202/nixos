local uv = vim.uv

local M = {}

local function schedule_call(fn, value)
  if type(fn) ~= "function" then
    return
  end

  vim.schedule(function()
    pcall(fn, value)
  end)
end

local function close_handle(handle)
  if not handle then
    return
  end

  if handle.is_closing and handle:is_closing() then
    return
  end

  pcall(handle.close, handle)
end

local function normalize_error(prefix, details)
  if details == nil or details == "" then
    return prefix
  end

  return string.format("%s: %s", prefix, tostring(details))
end

local function first_non_empty(...)
  local values = { ... }
  for _, value in ipairs(values) do
    if type(value) == "string" and value ~= "" then
      return value
    end
  end
  return nil
end

local function extract_content_list_text(content)
  if type(content) == "string" then
    return content
  end

  if type(content) ~= "table" then
    return nil
  end

  local chunks = {}
  for _, part in ipairs(content) do
    if type(part) == "string" then
      chunks[#chunks + 1] = part
    elseif type(part) == "table" then
      local txt = first_non_empty(part.text, part.delta, part.content)
      if txt then
        chunks[#chunks + 1] = txt
      end
    end
  end

  if #chunks == 0 then
    return nil
  end

  return table.concat(chunks)
end

local function collect_text_from_event(event)
  if type(event) ~= "table" then
    return nil
  end

  local typ = event.type
  local role = event.role

  if typ == "text_delta" or typ == "output_text_delta" then
    return first_non_empty(event.text, event.delta, event.content)
  end

  if typ == "assistant_message" or (typ == "message" and role == "assistant") then
    return first_non_empty(event.text, extract_content_list_text(event.content), event.message)
  end

  if role == "assistant" then
    return first_non_empty(
      event.text,
      event.delta,
      extract_content_list_text(event.content),
      type(event.message) == "table" and extract_content_list_text(event.message.content) or event.message
    )
  end

  if typ == "response" and event.success ~= false then
    if type(event.output) == "table" then
      return first_non_empty(event.output.text, event.output.content)
    end
    return first_non_empty(event.text, event.message)
  end

  return nil
end

local function parse_json_line(line)
  if line == nil then
    return true, nil
  end

  line = line:gsub("\r+$", "")
  if line == "" then
    return true, nil
  end

  local ok, decoded = pcall(vim.json.decode, line)
  if not ok then
    return false, string.format("malformed JSON from pi RPC: %s", line)
  end

  return true, decoded
end

local function build_prompt(opts)
  local bufnr = opts.bufnr
  local instruction = opts.instruction or ""

  local abs_path = vim.api.nvim_buf_get_name(bufnr)
  if abs_path == "" then
    abs_path = "[No Name]"
  else
    abs_path = vim.fn.fnamemodify(abs_path, ":p")
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == nil or filetype == "" then
    filetype = "plain"
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local body = table.concat(lines, "\n")

  return table.concat({
    "You are assisting inside Neovim.",
    "Return only insertion-ready text for placement below current cursor line.",
    "Do not include editor control chatter, tool logs, or markdown fences unless instruction explicitly asks.",
    "",
    "User instruction:",
    instruction,
    "",
    string.format("File path: %s", abs_path),
    string.format("Filetype: %s", filetype),
    "",
    "Current buffer:",
    "```",
    body,
    "```",
  }, "\n")
end

function M.ask_current_buffer(opts)
  opts = opts or {}

  local on_success = opts.on_success
  local on_error = opts.on_error

  local bufnr = opts.bufnr
  if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local instruction = opts.instruction
  if type(instruction) ~= "string" or instruction:gsub("%s+", "") == "" then
    schedule_call(on_error, "PiAsk: instruction is required")
    return
  end

  local prompt = build_prompt({ bufnr = bufnr, instruction = instruction })

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local state = {
    finalized = false,
    stdout_buf = "",
    stderr = {},
    text_chunks = {},
    parse_error = nil,
    rpc_error = nil,
    saw_message_end = false,
    saw_assistant_done = false,
    saw_agent_end = false,
    stdout_eof = false,
    exited = false,
    exit_code = nil,
    exit_signal = nil,
    handle = nil,
  }

  local function finalize(err)
    if state.finalized then
      return
    end
    state.finalized = true

    if stdout and stdout.read_stop then
      pcall(stdout.read_stop, stdout)
    end
    if stderr and stderr.read_stop then
      pcall(stderr.read_stop, stderr)
    end

    close_handle(stdin)
    close_handle(stdout)
    close_handle(stderr)
    close_handle(state.handle)

    if err then
      schedule_call(on_error, err)
      return
    end

    local text = table.concat(state.text_chunks)
    if text == "" then
      schedule_call(on_error, "PiAsk: no assistant text returned")
      return
    end

    schedule_call(on_success, text)
  end

  local function collect_error_detail(event)
    if type(event) ~= "table" then
      return nil
    end

    local detail = first_non_empty(
      event.error,
      event.message,
      event.reason,
      event.detail,
      event.details,
      type(event.code) == "string" and event.code,
      type(event.code) == "number" and tostring(event.code)
    )
    if detail then
      return detail
    end

    if type(event.message) == "table" then
      return first_non_empty(
        extract_content_list_text(event.message.content),
        event.message.text,
        event.message.reason
      )
    end

    return nil
  end

  local function consume_event(event)
    if type(event) ~= "table" then
      return
    end

    local typ = event.type

    if typ == "error" then
      state.rpc_error = normalize_error("PiAsk: stream error", collect_error_detail(event))
      return
    end

    if typ == "response" and event.success == false then
      state.rpc_error = normalize_error("PiAsk: request failed", first_non_empty(event.error, event.message))
      return
    end

    if typ == "message_end" then
      state.saw_message_end = true
    elseif typ == "agent_end" then
      state.saw_agent_end = true
    end

    if type(event.assistantMessageEvent) == "table" then
      local assistant_event = event.assistantMessageEvent
      if assistant_event.type == "error" then
        state.rpc_error = normalize_error("PiAsk: assistant stream error", collect_error_detail(assistant_event))
        return
      end

      if assistant_event.done == true then
        state.saw_assistant_done = true
      end
      local nested_text = collect_text_from_event(assistant_event)
      if nested_text then
        state.text_chunks[#state.text_chunks + 1] = nested_text
      end
    end

    local text = collect_text_from_event(event)
    if text then
      state.text_chunks[#state.text_chunks + 1] = text
    end
  end

  local function maybe_finalize()
    if state.finalized then
      return
    end

    if not (state.stdout_eof and state.exited) then
      return
    end

    if state.stdout_buf ~= "" then
      local ok, decoded_or_error = parse_json_line(state.stdout_buf)
      if not ok then
        state.parse_error = decoded_or_error
      else
        consume_event(decoded_or_error)
      end
      state.stdout_buf = ""
    end

    if state.parse_error then
      finalize("PiAsk: " .. state.parse_error)
      return
    end

    if state.rpc_error then
      finalize(state.rpc_error)
      return
    end

    if state.exit_code ~= 0 then
      local stderr_text = table.concat(state.stderr)
      local detail = string.format("pi exited with code %s", tostring(state.exit_code))
      if state.exit_signal and state.exit_signal ~= 0 then
        detail = detail .. string.format(" (signal %s)", tostring(state.exit_signal))
      end
      if stderr_text ~= "" then
        detail = detail .. string.format(": %s", stderr_text)
      end
      finalize("PiAsk: " .. detail)
      return
    end

    local saw_completion = state.saw_message_end or state.saw_assistant_done or state.saw_agent_end
    if not saw_completion and #state.text_chunks == 0 then
      finalize("PiAsk: no completion event or text from RPC")
      return
    end

    finalize(nil)
  end

  state.handle, state.spawn_error = uv.spawn("pi", {
    args = { "--mode", "rpc", "--no-session" },
    stdio = { stdin, stdout, stderr },
  }, function(code, signal)
    state.exited = true
    state.exit_code = code
    state.exit_signal = signal
    maybe_finalize()
  end)

  if not state.handle then
    close_handle(stdin)
    close_handle(stdout)
    close_handle(stderr)
    local msg = normalize_error("PiAsk: unable to spawn `pi` (check PATH)", state.spawn_error)
    schedule_call(on_error, msg)
    return
  end

  stdout:read_start(function(read_err, chunk)
    if read_err then
      finalize(normalize_error("PiAsk: stdout read failed", read_err))
      return
    end

    if not chunk then
      state.stdout_eof = true
      maybe_finalize()
      return
    end

    state.stdout_buf = state.stdout_buf .. chunk

    while true do
      local newline_at = state.stdout_buf:find("\n", 1, true)
      if not newline_at then
        break
      end

      local line = state.stdout_buf:sub(1, newline_at - 1)
      state.stdout_buf = state.stdout_buf:sub(newline_at + 1)

      local ok, decoded_or_error = parse_json_line(line)
      if not ok then
        state.parse_error = decoded_or_error
        finalize("PiAsk: " .. state.parse_error)
        return
      end

      consume_event(decoded_or_error)
      if state.rpc_error then
        finalize(state.rpc_error)
        return
      end
    end
  end)

  stderr:read_start(function(read_err, chunk)
    if read_err then
      state.stderr[#state.stderr + 1] = tostring(read_err)
      return
    end

    if chunk and chunk ~= "" then
      state.stderr[#state.stderr + 1] = chunk
    end
  end)

  local payload = vim.json.encode({ type = "prompt", message = prompt }) .. "\n"
  stdin:write(payload, function(write_err)
    if write_err then
      finalize(normalize_error("PiAsk: failed to write prompt", write_err))
      return
    end

    stdin:shutdown(function(shutdown_err)
      if shutdown_err then
        finalize(normalize_error("PiAsk: failed to close stdin", shutdown_err))
        return
      end

      close_handle(stdin)
    end)
  end)
end

return M
