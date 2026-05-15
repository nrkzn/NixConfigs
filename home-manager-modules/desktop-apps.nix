{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myHomeManager.desktopApps.enable = lib.mkEnableOption "common desktop GUI applications";
  };

  config = lib.mkIf config.myHomeManager.desktopApps.enable {
    home.packages = with pkgs; [
      vscode
      discord
      obsidian
      mpv
      vlc
      thunderbird
      libreoffice-fresh
      gimp
      obs-studio
      spotify
      xfce.thunar
      file-roller
      zathura
    ];
  };
}
