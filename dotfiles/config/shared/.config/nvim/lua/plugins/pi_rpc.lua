local function normalize_lines(payload)
  local typ = type(payload)

  if typ == "string" then
    return vim.split(payload, "\n", { plain = true })
  end

  if typ == "table" and vim.islist(payload) then
    return payload
  end

  if typ == nil then
    return {}
  end

  return { tostring(payload) }
end

local function insert_below_cursor(bufnr, text, row)
  local ok, lines = pcall(normalize_lines, text)
  if not ok then
    vim.notify("PiAsk: cannot parse response", vim.log.levels.ERROR)
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local safe_row = math.min(math.max(row, 1), line_count)
  vim.api.nvim_buf_set_lines(bufnr, safe_row, safe_row, false, lines)
end

local function notify_error(msg)
  local normalized = type(msg) == "string" and msg or vim.inspect(msg)
  vim.notify("PiAsk error: " .. normalized, vim.log.levels.ERROR)
end

local function setup_command()
  vim.api.nvim_create_user_command("PiAsk", function()
    vim.ui.input({ prompt = "PiAsk instruction: " }, function(input)
      if input == nil or input == "" then
        return
      end

      local bufnr = vim.api.nvim_get_current_buf()
      local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
      local ok, client = pcall(require, "pi_rpc.client")
      if not ok then
        notify_error("pi_rpc.client unavailable: " .. tostring(client))
        return
      end

      if type(client.ask_current_buffer) ~= "function" then
        notify_error("contract mismatch: ask_current_buffer not found")
        return
      end

      client.ask_current_buffer({
        bufnr = bufnr,
        instruction = input,
        on_success = function(result)
          insert_below_cursor(bufnr, result, cursor_row)
        end,
        on_error = function(err)
          notify_error(err)
        end,
      })
    end)
  end, {
    desc = "Ask Pi using current buffer context",
    nargs = 0,
  })
end

return {
  {
    name = "pi-rpc-commands",
    dir = vim.fn.stdpath("config"),
    config = function()
      setup_command()
    end,
  },
}
