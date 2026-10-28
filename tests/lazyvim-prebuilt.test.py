#!/usr/bin/env python3
"""Run after building thinkpad11e: exercise LazyVim without plugin downloads."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
projection = '''s: {
  nvim = "${s.pkgs.neovim}/bin/nvim";
  adapter = s.config.home-manager.users.hm.xdg.configFile."nvim/lua/config/nix.lua".text;
  tools = s.pkgs.lib.makeBinPath (with s.pkgs; [lua-language-server stylua shfmt nil]);
}'''
config = json.loads(subprocess.check_output([
    "nix", "eval", "--json", f"path:{root}#nixosConfigurations.thinkpad11e",
    "--apply", projection,
], text=True))
with tempfile.TemporaryDirectory(prefix="lazyvim-prebuilt-test-") as temporary:
    home = Path(temporary)
    shutil.copytree(root / "dotfiles/config/programs/neovim/.config/nvim", home / ".config/nvim")
    (home / ".config/nvim/lua/config/nix.lua").write_text(config["adapter"])
    sample = home / "sample.lua"
    sample.write_text("local sample = { value = 42 }\nprint(sample.value)\n")
    environment = dict(os.environ, HOME=temporary, PATH=config["tools"] + ":" + os.environ["PATH"])
    for directory in ("CONFIG", "DATA", "STATE", "CACHE"):
        environment[f"XDG_{directory}_HOME"] = str(home / directory.lower())
    environment["XDG_CONFIG_HOME"] = str(home / ".config")
    checks = '''
      assert(LazyVim.config.version)
      local config = require("lazy.core.config")
      assert(config.options.install.missing == false)
      assert(config.options.checker.enabled == false)
      assert(config.options.rocks.enabled == false)
      assert(config.plugins["LazyVim"] and not config.plugins["mason.nvim"])
      for name, plugin in pairs(config.plugins) do
        assert(plugin.dir:sub(1, 11) == "/nix/store/", name .. " escapes the Nix store")
      end
      assert(#vim.treesitter.get_parser(0, "lua"):parse() > 0)
      require("blink.cmp")
      assert(vim.v.errmsg == "", vim.v.errmsg)
      print("LazyVim " .. LazyVim.config.version .. ": prebuilt parser and completion OK")
    '''
    result = subprocess.run([
        config["nvim"], "--headless", str(sample), "+lua vim.wait(1500)",
        "+lua " + checks.replace("\n", " "), "+qa",
    ], env=environment, text=True, capture_output=True, timeout=60)
    output = result.stdout + result.stderr
    assert result.returncode == 0, output
    assert "prebuilt parser and completion OK" in output, output
    assert not any(message in output for message in (
        "Error in", "Failed to run", "No specs found", "not installed", "not found",
    )), output
    assert not (home / "data/lazy").exists(), "Startup downloaded plugins"
print("PASS: LazyVim loads Nix plugins, native Lua parsing and completion without downloads")
