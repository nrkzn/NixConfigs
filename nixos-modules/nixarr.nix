{
  config,
  lib,
  ...
}: let
  cfg = config.myNixOS.nixarr;

  # Helper: build a per-service option set (enable / port / vpn-routing)
  mkServiceOpts = {
    name,
    defaultPort,
    defaultEnable ? true,
    defaultVpn ? false,
  }: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = defaultEnable;
      description = "Enable ${name}.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "Listening port for ${name}.";
    };
    vpn.enable = lib.mkOption {
      type = lib.types.bool;
      default = defaultVpn;
      description = "Route ${name} through the VPN container.";
    };
  };
in {
  options.myNixOS.nixarr = {
    enable = lib.mkEnableOption "Nixarr media stack (Jellyfin + *arr suite + Transmission)";

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/media";
      description = "Root directory for the media library.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/nixarr";
      description = "Root directory for Nixarr service state.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open per-service ports on the LAN firewall.";
    };

    # ----- VPN -----
    vpn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Route torrent traffic (and optionally *arr services) through a
          WireGuard VPN. When enabled, you must provide `vpn.wgConfFile`.
        '';
      };
      wgConfFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/wg0.conf";
        description = ''
          Path to a WireGuard config file (provided by the VPN). Must be
          readable only by root — keep it out of the Nix store (use sops/
          agenix or place it in /etc directly).
        '';
      };
      accessibleFrom = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["10.1.1.0/24"];
        description = ''
          Additional LAN subnets that should be allowed to reach VPN-routed
          services via Nixarr's internal nginx reverse proxy. Nixarr already
          allows 192.168.0.0/24, 192.168.1.0/24, and 127.0.0.1 by default —
          use this for non-standard LAN ranges (e.g. 10.x.x.x).
        '';
      };
      vpnTestService.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Spin up a one-shot service that prints the VPN exit IP for verification.";
      };
    };

    # ----- Jellyfin -----
    jellyfin = (mkServiceOpts {
      name = "Jellyfin";
      defaultPort = 8096;
    }) // {
      expose.https = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Expose Jellyfin publicly over HTTPS via nginx + ACME.";
        };
        domainName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "jelly.example.com";
          description = "Public domain name to serve Jellyfin from.";
        };
        acmeMail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "admin@example.com";
          description = "Contact email for Let's Encrypt registration.";
        };
      };
    };

    # ----- Transmission -----
    transmission = (mkServiceOpts {
      name = "Transmission";
      defaultPort = 9091;
      defaultVpn = true;
    }) // {
      peerPort = lib.mkOption {
        type = lib.types.port;
        default = 50000;
        description = "BitTorrent peer port (forwarded by the VPN).";
      };
      uiPassword = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Web UI password. If null, the UI is bound to localhost only.
          NOTE: ends up in the Nix store — only set on trusted hosts or
          wire it through sops/agenix.
        '';
      };
      downloadDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.mediaDir}/torrents";
        defaultText = lib.literalExpression ''"''${cfg.mediaDir}/torrents"'';
        description = "Where Transmission writes completed downloads.";
      };
    };

    # ----- *arr services -----
    sonarr = mkServiceOpts {
      name = "Sonarr";
      defaultPort = 8989;
    };
    radarr = mkServiceOpts {
      name = "Radarr";
      defaultPort = 7878;
    };
    prowlarr = mkServiceOpts {
      name = "Prowlarr";
      defaultPort = 9696;
      # Default off the VPN — Prowlarr only queries indexer APIs and doesn't
      # touch the torrent swarm. See host config for the full rationale.
      defaultVpn = false;
    };
    bazarr = mkServiceOpts {
      name = "Bazarr";
      defaultPort = 6767;
    };
    # Shelfmark — book/audiobook search + download hub (the Readarr replacement
    # the user asked for; Nixarr does ship a module for it).
    shelfmark = (mkServiceOpts {
      name = "Shelfmark";
      defaultPort = 8084;
      defaultEnable = false;
    }) // {
      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address Shelfmark binds its HTTP server to.";
      };
      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.stateDir}/shelfmark";
        defaultText = lib.literalExpression ''"''${cfg.stateDir}/shelfmark"'';
        description = "Where Shelfmark stores its state (DB, config).";
      };
    };

    lidarr = mkServiceOpts {
      name = "Lidarr";
      defaultPort = 8686;
      defaultEnable = false;
    };
    seerr = (mkServiceOpts {
      name = "Jellyseerr (nixarr.seerr)";
      defaultPort = 5055;
      defaultEnable = false;
    }) // {
      expose.https = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Expose Jellyseerr publicly over HTTPS via nginx + ACME.";
        };
        domainName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Public domain name to serve Jellyseerr from.";
        };
        acmeMail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Contact email for Let's Encrypt registration.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.vpn.enable || cfg.vpn.wgConfFile != null;
        message = "myNixOS.nixarr.vpn.enable = true requires myNixOS.nixarr.vpn.wgConfFile to be set.";
      }
      {
        assertion = !cfg.jellyfin.expose.https.enable
          || (cfg.jellyfin.expose.https.domainName != null
              && cfg.jellyfin.expose.https.acmeMail != null);
        message = "Exposing Jellyfin over HTTPS requires both domainName and acmeMail.";
      }
      {
        assertion = !cfg.seerr.expose.https.enable
          || (cfg.seerr.expose.https.domainName != null
              && cfg.seerr.expose.https.acmeMail != null);
        message = "Exposing Jellyseerr over HTTPS requires both domainName and acmeMail.";
      }
    ];

    nixarr = {
      enable = true;
      mediaDir = cfg.mediaDir;
      stateDir = cfg.stateDir;

      vpn = lib.mkIf cfg.vpn.enable {
        enable = true;
        wgConf = cfg.vpn.wgConfFile;
        vpnTestService.enable = cfg.vpn.vpnTestService.enable;
        accessibleFrom = cfg.vpn.accessibleFrom;
      };

      jellyfin = {
        enable = cfg.jellyfin.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.jellyfin.vpn.enable;
        expose.https = lib.mkIf cfg.jellyfin.expose.https.enable {
          enable = true;
          domainName = cfg.jellyfin.expose.https.domainName;
          acmeMail = cfg.jellyfin.expose.https.acmeMail;
        };
      };

      transmission = {
        enable = cfg.transmission.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.transmission.vpn.enable;
        peerPort = cfg.transmission.peerPort;
        uiPort = cfg.transmission.port;
        flood.enable = false;
        extraSettings =
          {
            download-dir = cfg.transmission.downloadDir;
            incomplete-dir = "${cfg.transmission.downloadDir}/.incomplete";
            incomplete-dir-enabled = true;
            ratio-limit = 2.0;
            ratio-limit-enabled = true;
            speed-limit-up = 2000;
            speed-limit-up-enabled = true;
            # Bind on all interfaces but rely on the host firewall to scope
            # access to the LAN. RPC whitelist is enforced by Transmission
            # itself as a second layer.
            #
            # The whitelist includes:
            #   - 127.0.0.1 / *.*.*.* host loopback
            #   - 10.1.1.* the LAN
            #   - 10.* covers RFC1918 private space the netns bridge uses,
            #     which is what *arr settings-sync queries from
            rpc-bind-address = "0.0.0.0";
            rpc-host-whitelist-enabled = false;
            rpc-whitelist-enabled = true;
            rpc-whitelist = "127.0.0.1,10.*.*.*,192.168.*.*";
          }
          // lib.optionalAttrs (cfg.transmission.uiPassword != null) {
            rpc-authentication-required = true;
            rpc-username = "nathan";
            rpc-password = cfg.transmission.uiPassword;
          };
      };

      sonarr = {
        enable = cfg.sonarr.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.sonarr.vpn.enable;
      };

      radarr = {
        enable = cfg.radarr.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.radarr.vpn.enable;
      };

      prowlarr = {
        enable = cfg.prowlarr.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.prowlarr.vpn.enable;
      };

      bazarr = {
        enable = cfg.bazarr.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.bazarr.vpn.enable;
      };

      lidarr = {
        enable = cfg.lidarr.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.lidarr.vpn.enable;
      };

      shelfmark = {
        enable = cfg.shelfmark.enable;
        openFirewall = cfg.openFirewall;
        host = cfg.shelfmark.host;
        port = cfg.shelfmark.port;
        stateDir = cfg.shelfmark.stateDir;
        vpn.enable = cfg.shelfmark.vpn.enable;
      };

      seerr = {
        enable = cfg.seerr.enable;
        openFirewall = cfg.openFirewall;
        vpn.enable = cfg.seerr.vpn.enable;
        expose.https = lib.mkIf cfg.seerr.expose.https.enable {
          enable = true;
          domainName = cfg.seerr.expose.https.domainName;
          acmeMail = cfg.seerr.expose.https.acmeMail;
        };
      };
    };

    # Pre-create the media directory tree before any service starts.
    #
    # Nixarr's own convention puts imported/organized library content under
    # `${mediaDir}/library/<service>/` — that's what each *arr app sees as
    # its root folder. Downloads land in `${mediaDir}/torrents/` (separate
    # from library, on the same filesystem, so the *arr apps can hardlink
    # finished files into the library without duplicating disk usage).
    #
    # `Z` (capital) on the top dirs CREATES if missing AND recursively
    # fixes ownership — corrects /data/media being root-owned from
    # Nixarr's pre-media-user init phase.
    systemd.tmpfiles.rules = [
      "Z ${cfg.mediaDir}                            0775 media media -"
      "Z ${cfg.mediaDir}/library                    0775 media media -"
      "d ${cfg.mediaDir}/library/movies             0775 media media -"
      "d ${cfg.mediaDir}/library/shows              0775 media media -"
      "d ${cfg.mediaDir}/library/music              0775 media media -"
      "d ${cfg.mediaDir}/library/books              0775 media media -"
      "Z ${cfg.mediaDir}/torrents                   0775 media media -"
      "d ${cfg.transmission.downloadDir}            0775 media media -"
      "d ${cfg.transmission.downloadDir}/.incomplete 0775 media media -"
    ];
  };
}
