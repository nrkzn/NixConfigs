{
  config,
  lib,
  ...
}: {
  options = {
    myHomeManager.waybar.enable = lib.mkEnableOption "waybar status bar";
  };

  config = lib.mkIf config.myHomeManager.waybar.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;

        modules-left = ["hyprland/workspaces" "hyprland/window"];
        modules-center = ["clock"];
        modules-right = ["pulseaudio" "network" "cpu" "memory" "battery" "tray"];

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
        };

        clock = {
          format = "{:%a %b %d  %H:%M}";
          tooltip-format = "<tt>{calendar}</tt>";
        };

        cpu.format = " {usage}%";
        memory.format = " {}%";

        battery = {
          format = "{icon} {capacity}%";
          format-icons = ["" "" "" "" ""];
        };

        network = {
          format-wifi = " {essid}";
          format-ethernet = " {ipaddr}";
          format-disconnected = "⚠ off";
          tooltip-format = "{ifname}: {ipaddr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = " muted";
          format-icons.default = ["" "" ""];
          on-click = "pavucontrol";
        };

        tray.spacing = 8;
      };

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", sans-serif;
          font-size: 13px;
          min-height: 0;
        }
        window#waybar {
          background-color: rgba(40, 40, 40, 0.85);
          color: #ebdbb2;
          border-bottom: 2px solid #458588;
        }
        #workspaces button {
          padding: 0 8px;
          color: #a89984;
        }
        #workspaces button.active {
          color: #fabd2f;
          border-bottom: 2px solid #fabd2f;
        }
        #clock, #cpu, #memory, #network, #pulseaudio, #battery, #tray {
          padding: 0 10px;
        }
      '';
    };
  };
}
