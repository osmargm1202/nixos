{ config, lib, pkgs, userName, ... }:
let
  enabled = config.orgm.neovim.prebuilt && builtins.elem "neovim" config.orgm.user.programs;
  treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: with p; [
    bash c css diff html javascript jsdoc json lua luadoc markdown
    markdown_inline nix python query regex toml tsx typescript vim vimdoc xml yaml
  ]);
  collectDependencies = plugins: lib.unique (lib.concatMap
    (plugin: [ plugin ] ++ collectDependencies (plugin.dependencies or [ ])) plugins);
  parserRuntime = pkgs.symlinkJoin {
    name = "lazyvim-prebuilt-parsers";
    paths = collectDependencies treesitter.dependencies;
  };
  plugins = with pkgs.vimPlugins; {
    "LazyVim/LazyVim" = LazyVim;
    "folke/lazy.nvim" = lazy-nvim;
    "saghen/blink.cmp" = blink-cmp;
    "akinsho/bufferline.nvim" = bufferline-nvim;
    "catppuccin/nvim" = catppuccin-nvim;
    "stevearc/conform.nvim" = conform-nvim;
    "folke/flash.nvim" = flash-nvim;
    "rafamadriz/friendly-snippets" = friendly-snippets;
    "lewis6991/gitsigns.nvim" = gitsigns-nvim;
    "MagicDuck/grug-far.nvim" = grug-far-nvim;
    "folke/lazydev.nvim" = lazydev-nvim;
    "nvim-lualine/lualine.nvim" = lualine-nvim;
    "nvim-mini/mini.ai" = mini-ai;
    "nvim-mini/mini.icons" = mini-icons;
    "nvim-mini/mini.pairs" = mini-pairs;
    "folke/noice.nvim" = noice-nvim;
    "MunifTanjim/nui.nvim" = nui-nvim;
    "mfussenegger/nvim-lint" = nvim-lint;
    "neovim/nvim-lspconfig" = nvim-lspconfig;
    "nvim-treesitter/nvim-treesitter" = treesitter;
    "nvim-treesitter/nvim-treesitter-textobjects" = nvim-treesitter-textobjects;
    "windwp/nvim-ts-autotag" = nvim-ts-autotag;
    "folke/persistence.nvim" = persistence-nvim;
    "nvim-lua/plenary.nvim" = plenary-nvim;
    "folke/snacks.nvim" = snacks-nvim;
    "folke/todo-comments.nvim" = todo-comments-nvim;
    "folke/tokyonight.nvim" = tokyonight-nvim;
    "folke/trouble.nvim" = trouble-nvim;
    "folke/ts-comments.nvim" = ts-comments-nvim;
    "folke/which-key.nvim" = which-key-nvim;
  };
  specs = lib.mapAttrsToList (repo: plugin: {
    "1" = repo;
    name = if repo == "catppuccin/nvim" then "catppuccin" else builtins.baseNameOf repo;
    dir = toString plugin;
  }) plugins;
in {
  options.orgm.neovim.prebuilt = lib.mkEnableOption "LazyVim with Nix-supplied plugins, parsers and language tools";
  config = lib.mkIf enabled {
    environment.systemPackages = with pkgs; [
      neovim lua-language-server stylua shfmt nil
    ];
    home-manager.users.${userName}.xdg.configFile."nvim/lua/config/nix.lua".text = ''
      -- Adapter only: personal options/keymaps/plugins remain editable dotfiles.
      vim.opt.rtp:prepend("${pkgs.vimPlugins.lazy-nvim}")
      vim.g.snacks_animate = false
      local specs = {}
      local paths = vim.json.decode([==[${builtins.toJSON specs}]==])
      for _, plugin in ipairs(paths) do
        table.insert(specs, { plugin["1"], name = plugin.name, dir = plugin.dir, build = false, pin = true })
      end
      vim.list_extend(specs, {
        { "LazyVim/LazyVim", dir = "${pkgs.vimPlugins.LazyVim}", import = "lazyvim.plugins", opts = { news = { lazyvim = false, neovim = false } } },
        { import = "plugins" },
        { "mason-org/mason.nvim", enabled = false },
        { "mason-org/mason-lspconfig.nvim", enabled = false },
        { "nvim-treesitter/nvim-treesitter", opts = function(_, opts)
          opts.ensure_installed = {}
          opts.auto_install = false
          opts.install_dir = "${parserRuntime}"
        end },
        { "saghen/blink.cmp", opts = { fuzzy = { implementation = "lua" } } },
        { "neovim/nvim-lspconfig", opts = { servers = {
          lua_ls = { mason = false }, nil_ls = { mason = false },
        } } },
        { "folke/snacks.nvim", opts = { animate = { enabled = false } } },
      })
      require("lazy").setup({
        spec = specs,
        defaults = { lazy = false, version = false },
        install = { missing = false, colorscheme = { "tokyonight", "habamax" } },
        checker = { enabled = false },
        change_detection = { enabled = false, notify = false },
        rocks = { enabled = false },
        pkg = { enabled = false },
      })
    '';
  };
}
