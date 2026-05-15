{
  config,
  lib,
  ...
}: {
  options = {
    myNixOS.networking = {
      enable = lib.mkEnableOption "NetworkManager + firewall defaults";
      hostName = lib.mkOption {
        type = lib.types.str;
        default = "nixos";
        description = "Host name for this machine";
      };
    };
  };

  config = lib.mkIf config.myNixOS.networking.enable {
    networking.hostName = config.myNixOS.networking.hostName;
    networking.networkmanager.enable = true;

    networking.firewall = {
      enable = true;
      allowPing = true;
    };
  };
}
