{
  config,
  pkgs,
  lib,
  ...
}: {
  myHomeManager = {
    core.enable = true;
    git.enable = true;
    zsh.enable = true;
    tmux.enable = true;
    neovim.enable = true;

    # No GUI on the server
    kitty.enable = false;
    hyprland.enable = false;
    waybar.enable = false;
    firefox.enable = false;
    desktopApps.enable = false;
  };

  home.username = "nathan";
  home.homeDirectory = "/home/nathan";
  home.stateVersion = "24.11";
}
