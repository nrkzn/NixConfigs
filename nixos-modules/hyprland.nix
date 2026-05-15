{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  options = {
    myNixOS.hyprland.enable = lib.mkEnableOption "Hyprland Wayland compositor + display manager";
  };

  config = lib.mkIf config.myNixOS.hyprland.enable {
    # Hyprland on llvmpipe (software rendering) technically works but is
    # unusable. Catch the "forgot to flip a GPU module" case at eval time.
    assertions = [{
      assertion = config.myNixOS.gpu.nvidia.enable
        || config.myNixOS.gpu.amd.enable
        || config.hardware.graphics.enable or false;
      message = ''
        Hyprland is enabled but no GPU module is. Set either
        `myNixOS.gpu.nvidia.enable = true` or `myNixOS.gpu.amd.enable = true`
        (or enable `hardware.graphics` directly if you're on Intel iGPU).
      '';
    }];

    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
      xwayland.enable = true;
    };

    # Login manager — tuigreet on tty for a minimal Wayland-friendly greeter
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
          user = "greeter";
        };
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_SESSION_TYPE = "wayland";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    environment.systemPackages = with pkgs; [
      wl-clipboard
      grim
      slurp
      hyprpicker
      hyprcursor
      brightnessctl
      playerctl
      pavucontrol
      networkmanagerapplet
      polkit_gnome
    ];

    security.polkit.enable = true;
    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
    };
  };
}
