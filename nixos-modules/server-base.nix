{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.serverBase.enable = lib.mkEnableOption "headless server baseline (no GUI, journald limits, fail2ban)";
  };

  config = lib.mkIf config.myNixOS.serverBase.enable {
    # Headless: no graphical target
    services.xserver.enable = lib.mkDefault false;

    services.journald.extraConfig = ''
      SystemMaxUse=500M
      MaxRetentionSec=1month
    '';

    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
    };

    environment.systemPackages = with pkgs; [
      tmux
      iotop
      iftop
      ncdu
      smartmontools
      lm_sensors
      wireguard-tools  # `wg show` for VPN debugging
      dnsutils         # nslookup / dig for DNS debugging
      libnatpmp        # `natpmpc` for NAT-PMP port-forward debugging
    ];

    # No automatic suspend on a server
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
