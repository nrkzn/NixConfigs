{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myHomeManager.neovim.enable = lib.mkEnableOption "neovim with a sensible default config";
  };

  config = lib.mkIf config.myHomeManager.neovim.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      plugins = with pkgs.vimPlugins; [
        nvim-treesitter.withAllGrammars
        telescope-nvim
        plenary-nvim
        nvim-lspconfig
        gruvbox-nvim
        lualine-nvim
        nvim-web-devicons
        which-key-nvim
        comment-nvim
        gitsigns-nvim
      ];

      extraLuaConfig = ''
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.expandtab = true
        vim.opt.shiftwidth = 2
        vim.opt.tabstop = 2
        vim.opt.smartindent = true
        vim.opt.termguicolors = true
        vim.opt.signcolumn = "yes"
        vim.opt.clipboard = "unnamedplus"
        vim.opt.scrolloff = 8

        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

        vim.cmd.colorscheme("gruvbox")

        require("lualine").setup({ options = { theme = "gruvbox" } })
        require("gitsigns").setup()
        require("Comment").setup()
        require("which-key").setup()

        local telescope = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", telescope.find_files)
        vim.keymap.set("n", "<leader>fg", telescope.live_grep)
        vim.keymap.set("n", "<leader>fb", telescope.buffers)
      '';
    };
  };
}
