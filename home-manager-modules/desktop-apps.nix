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
      # discord — removed: depends on insecure OpenSSL 1.1 in current nixpkgs.
      # If you want it back, either add `nixpkgs.config.permittedInsecurePackages
      # = ["openssl-1.1.1w"];` somewhere, or use vesktop (a forked client that
      # doesn't have the OpenSSL dependency): add `vesktop` here instead.
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
