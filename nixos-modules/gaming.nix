{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.gaming.enable = lib.mkEnableOption "Steam + gamemode + gamescope";
  };

  config = lib.mkIf config.myNixOS.gaming.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
    };

    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      mangohud
      protonup-qt
      lutris
      heroic
    ];
  };
}
