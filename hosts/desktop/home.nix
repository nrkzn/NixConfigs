{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  myHomeManager = {
    core.enable = true;
    git.enable = true;
    zsh.enable = true;
    tmux.enable = true;
    neovim.enable = true;
    kitty.enable = true;
    hyprland.enable = true;
    waybar.enable = true;
    firefox.enable = true;
    desktopApps.enable = true;
  };

  home.username = "nathan";
  home.homeDirectory = "/home/nathan";
  home.stateVersion = "24.11";
}
