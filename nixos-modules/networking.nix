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

    # Switch the firewall backend to nftables. Required for
    # `networking.firewall.extraInputRules` (used on the mediaserver to scope
    # service ports to the LAN subnet). Default backend in current nixpkgs is
    # still iptables-legacy on some module sets — flipping this opts into nft.
    networking.nftables.enable = true;

    networking.firewall = {
      enable = true;
      allowPing = true;
    };
  };
}
