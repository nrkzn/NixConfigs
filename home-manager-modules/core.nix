{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myHomeManager.core.enable = lib.mkEnableOption "core home baseline (XDG dirs, common CLI pkgs)";
  };

  config = lib.mkIf config.myHomeManager.core.enable {
    home.username = lib.mkDefault "nathan";
    home.homeDirectory = lib.mkDefault "/home/nathan";
    home.stateVersion = lib.mkDefault "25.11";

    xdg.enable = true;
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
    };

    home.packages = with pkgs; [
      bat
      eza
      fzf
      zoxide
      ripgrep
      fd
      jq
      yq
      htop
      btop
      duf
      ncdu
      tldr
      neofetch
    ];

    programs.home-manager.enable = true;
  };
}
