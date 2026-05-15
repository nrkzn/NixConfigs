{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.users.enable = lib.mkEnableOption "primary user 'nathan'";
  };

  config = lib.mkIf config.myNixOS.users.enable {
    users.users.nathan = {
      isNormalUser = true;
      description = "Nathan";
      shell = pkgs.zsh;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "audio"
        "input"
        "render"
      ];
    };
  };
}
