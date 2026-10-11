{
  config,
  options,
  pkgs,
  lib,
  ...
}: let
  journalLimits = {
    SystemMaxUse = "500M";
    MaxRetentionSec = "1month";
  };
in {
  options = {
    myNixOS.serverBase.enable = lib.mkEnableOption "headless server baseline (no GUI, journald limits, fail2ban)";
  };

  config = lib.mkIf config.myNixOS.serverBase.enable {
    # Headless: no graphical target
    services.xserver.enable = lib.mkDefault false;

    # nixpkgs (Oct 2026) replaced journald.extraConfig with settings.Journal
    # and now rejects the old option. Lock files are per machine, so support
    # both until every host is past the change.
    services.journald =
      if options.services.journald ? settings
      then {settings.Journal = journalLimits;}
      else {
        extraConfig = lib.concatStrings (lib.mapAttrsToList (k: v: "${k}=${v}\n") journalLimits);
      };

    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
      # Never ban the home LAN — a few bad key attempts shouldn't lock us out.
      ignoreIP = ["10.1.1.0/24"];
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

    # Laptop-as-server: closing the lid must not suspend or power off,
    # whether on battery, on AC, or docked.
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    # No automatic suspend on a server
    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
