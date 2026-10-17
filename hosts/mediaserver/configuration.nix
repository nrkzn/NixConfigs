{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./recyclarr.nix
    ./monitoring.nix
    ./music-genres.nix
  ];

  # Pin to 6.6 LTS — the legacy 470 NVIDIA driver (required for the GTX
  # 970M / Maxwell) doesn't track current kernels. As of nixpkgs 25.05+,
  # `nvidiaPackages.legacy_470` only reliably builds against 6.6.x.
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  myNixOS = {
    core.enable = true;
    boot.enable = true;
    users.enable = true;
    fonts.enable = true;
    ssh.enable = true;
    serverBase.enable = true;

    networking = {
      enable = true;
      hostName = "holodeck";
    };

    nixarr = {
      enable = true;
      mediaDir = "/data/media";
      # App state (SQLite DBs, Jellyfin metadata + transcode cache, API keys,
      # Transmission resume data) on the NVMe SSD. On the 5400 rpm /data HDD
      # it competed with torrent I/O ("database is locked", stalled UIs).
      stateDir = "/var/lib/nixarr";
      # Do NOT auto-open service ports on the host firewall — every service
      # below relies on the per-service `openFirewall = false` default so
      # nothing is reachable from off-host without an SSH tunnel / VPN in.
      openFirewall = false;

      # WireGuard config at /etc/nixarr/wg.conf (root:root, 0400) — keep it
      # out of the Nix store. Transmission rides this tunnel; Prowlarr does
      # not (vpn.enable = false on it for faster indexer queries).
      vpn = {
        enable = true;
        wgConfFile = "/etc/nixarr/wg.conf";
        vpnTestService.enable = true;
        # Nixarr's nginx reverse proxy only allows 192.168.x.x by default.
        # Our LAN is 10.1.1.0/24 — extend the allow list.
        accessibleFrom = ["10.1.1.0/24"];
        # ProtonVPN gives a dynamic forwarded port via NAT-PMP. Lease it,
        # renew it, and push it into Transmission live.
        portForward.enable = true;
      };

      jellyfin = {
        enable = true;
        port = 8096;
        # Set domainName + acmeMail and flip enable to expose publicly.
        expose.https = {
          enable = false;
          domainName = null;
          acmeMail = null;
        };
      };

      transmission = {
        enable = true;
        port = 9091;
        # peerPort is just the initial value; the protonvpn-natpmp service
        # overrides it at runtime with whatever port Proton leases via NAT-PMP.
        peerPort = 50000;
        vpn.enable = true;
        downloadDir = "/data/media/torrents";
        uiPassword = null;
      };

      sonarr = {
        enable = true;
        port = 8989;
      };

      radarr = {
        enable = true;
        port = 7878;
      };

      prowlarr = {
        enable = true;
        port = 9696;
        # Prowlarr just hits indexer APIs to fetch search results; it doesn't
        # transfer torrent data itself. Keeping it OFF the VPN avoids the
        # nginx-proxy-into-netns complication and gives faster searches.
        # Flip vpn.enable = true if your threat model includes hiding which
        # indexers you query from your ISP.
        vpn.enable = false;
      };

      bazarr = {
        enable = true;
        port = 6767;
      };

      # Shelfmark — book/audiobook search + download hub (Readarr replacement).
      shelfmark = {
        enable = true;
        port = 8084;
      };

      lidarr = {
        enable = true;
        port = 8686;
      };

      # Jellyseerr lives under `nixarr.seerr.*` in upstream, not `jellyseerr.*`.
      seerr = {
        enable = true;
        port = 5055;
      };
    };

    # No audio, bluetooth, or Hyprland on the server
    audio.enable = false;
    bluetooth.enable = false;
    hyprland.enable = false;
    gaming.enable = false;

    # NVIDIA GPU for Jellyfin NVENC/NVDEC transcoding (headless: no X).
    # GTX 970M is Maxwell — last supported on the legacy 470 driver branch.
    # Capabilities: H.264 encode/decode, VP9 decode, MPEG-2/VC-1 decode.
    # No HEVC encode, no HEVC 10-bit, no AV1, no open kernel modules.
    #
    # If `nvidia-smi` reports "no devices found" after rebuild, the 470
    # driver is incompatible with the current kernel. Pin the 6.6 LTS:
    #   boot.kernelPackages = pkgs.linuxPackages_6_6;
    # (uncomment the line below the imports list).
    gpu.nvidia = {
      enable = true;
      headless = true;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    };

    virtualisation = {
      docker.enable = true;
      libvirt.enable = false;
    };
  };

  # --------------------------------------------------------------------------
  # Nixarr settings-sync — declaratively wire the *arr stack together so it
  # matches the TRaSH-Guides "everything talks to everything" baseline:
  #   - Prowlarr is the single source of indexers, pushed to Sonarr/Radarr/Lidarr
  #   - Sonarr + Radarr each have Transmission as their download client
  #   - Bazarr pulls its library list from Sonarr + Radarr
  # Quality profiles, custom formats, quality sizes and naming come from
  # Recyclarr instead — see ./recyclarr.nix. The remaining manual steps are
  # in [README.md](../../README.md#trash-guides-followup).
  # --------------------------------------------------------------------------
  nixarr.prowlarr.settings-sync = {
    enable-nixarr-apps = true;  # auto-wires Prowlarr → every enabled *arr via internal API keys
    # Lidarr: "Add and Remove Only", so Prowlarr doesn't overwrite per-indexer
    # settings made in Lidarr — its indexers use seed ratio 1 (music imports
    # are copies that get removed once seeded; video keeps the global 2.0).
    lidarr.config.syncLevel = "addOnly";
  };

  # Nixarr's `transmission` shortcut auto-fills host/port/useSsl. Each *arr
  # also gets its own category (TRaSH-Guides): Transmission then saves its
  # downloads in a /data/media/torrents/<category> subfolder, and each app
  # only tracks its own downloads instead of every torrent in the client.
  # Field names are the *arr API's (tvCategory/movieCategory); inspect with
  #   sudo nixarr show-sonarr-schemas download_client | jq '.'
  # Lidarr isn't covered by Nixarr's settings-sync: set Category = lidarr in
  # its UI (Settings → Download Clients → Transmission).
  nixarr.sonarr.settings-sync.transmission = {
    enable = true;
    config.fields.tvCategory = "sonarr";
  };
  nixarr.radarr.settings-sync.transmission = {
    enable = true;
    config.fields.movieCategory = "radarr";
  };

  # apiKeyFile is left to Nixarr's default (${nixarr.stateDir}/secrets/*.api-key);
  # don't hard-code it here or a future Nixarr refactor will silently
  # disconnect this from the *arr-generated key.
  nixarr.bazarr.settings-sync = {
    sonarr = {
      enable = true;
      config = {
        ip = "127.0.0.1";
        port = config.myNixOS.nixarr.sonarr.port;
        ssl = false;
        base_url = "";
        sync_only_monitored_series = true;
        sync_only_monitored_episodes = true;
      };
    };
    radarr = {
      enable = true;
      config = {
        ip = "127.0.0.1";
        port = config.myNixOS.nixarr.radarr.port;
        ssl = false;
        base_url = "";
        sync_only_monitored_movies = true;
      };
    };
  };

  # --------------------------------------------------------------------------
  # Secrets (sops-nix). Decrypted at activation with this host's SSH host key
  # (converted to age), so no extra key lives on the server. Recipients are
  # listed in /.sops.yaml; edit with `sops secrets/mediaserver.yaml`.
  # Secrets default to root:root 0400 under /run/secrets/.
  # --------------------------------------------------------------------------
  sops = {
    defaultSopsFile = ../../secrets/mediaserver.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    # Secrets are age-only; don't import the RSA host key as a GPG key
    # (sops-nix does that by default).
    gnupg.sshKeyPaths = [];
    secrets.cloudflared-holodeck = {};
  };

  # --------------------------------------------------------------------------
  # Cloudflare Tunnel — public access to Jellyfin + Jellyseerr with no open
  # inbound ports (cloudflared dials out). Locally managed: routing lives
  # here, not in the dashboard. Created once with
  #   nix-shell -p cloudflared
  #   cloudflared tunnel login && cloudflared tunnel create holodeck
  # and its credentials JSON stored as the `cloudflared-holodeck` secret.
  #
  # Tunnel traffic arrives from 127.0.0.1, so NEVER route an *arr app here:
  # their `DisabledForLocalAddresses` auth would let anyone in. Jellyfin and
  # Jellyseerr enforce their own logins.
  # --------------------------------------------------------------------------
  services.cloudflared = {
    enable = true;
    # Attr name must be the tunnel UUID (a tunnel *name* would need cert.pem
    # on the server to resolve it).
    tunnels."7b08523b-e24a-4ac3-8fe5-273aebfedc32" = {
      credentialsFile = config.sops.secrets.cloudflared-holodeck.path;
      default = "http_status:404";
      # Keep hostnames one level under kozian.cloud so Cloudflare's free
      # Universal SSL (*.kozian.cloud) covers them.
      ingress = {
        "watch.kozian.cloud" = "http://localhost:${toString config.myNixOS.nixarr.jellyfin.port}";
        "holo.kozian.cloud" = "http://localhost:${toString config.myNixOS.nixarr.seerr.port}";
      };
    };
  };

  # --------------------------------------------------------------------------
  # Fixed LAN address. 10.1.1.5 is outside the FRITZ!Box's DHCP range, so it
  # can't collide with a DHCP lease, and the IP no longer changes on reboot.
  # --------------------------------------------------------------------------
  networking.networkmanager = {
    ensureProfiles.profiles.lan = {
      connection = {
        id = "lan";
        type = "ethernet";
        interface-name = "enp3s0";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4 = {
        method = "manual";
        address1 = "10.1.1.5/24,10.1.1.1"; # address/prefix,gateway
        dns = "10.1.1.1;";
      };
      ipv6.method = "auto";
    };
    # Don't auto-create a DHCP "Wired connection 1" next to the profile above.
    settings.main.no-auto-default = "interface-name:enp3s0";
  };

  time.timeZone = "America/New_York";

  # Firewall: SSH is reachable from anywhere (opened by myNixOS.ssh). All
  # Nixarr service ports are reachable ONLY from the 10.1.1.0/24 LAN.
  # The default allowedTCPPorts list stays empty so nothing leaks if the box
  # ever ends up on a public IP — LAN access is granted by nftables rules
  # matched on source address.
  networking.firewall.allowedTCPPorts = [];
  networking.firewall.allowedUDPPorts = [];

  networking.firewall.extraInputRules = ''
    ip saddr 10.1.1.0/24 tcp dport { 8096, 8920, 8989, 7878, 9696, 6767, 9091, 5055, 8686, 8084 } accept comment "nixarr web UIs (LAN only)"
    ip saddr 10.1.1.0/24 tcp dport 3000 accept comment "grafana (LAN only)"
    ip saddr 10.1.1.0/24 udp dport { 1900, 7359 } accept comment "jellyfin DLNA + autodiscover (LAN only)"
  '';

  # On a fresh install, Sonarr/Radarr need to start once before they write
  # their API-key files at ${stateDir}/secrets/{sonarr,radarr}.api-key.
  # Bazarr's settings-sync reads those at startup — on a clean machine the
  # files don't exist yet, so order Bazarr after them and let it retry.
  systemd.services.bazarr = {
    after = ["sonarr.service" "radarr.service"];
    wants = ["sonarr.service" "radarr.service"];
    serviceConfig = {
      Restart = lib.mkForce "on-failure";
      RestartSec = 30;
    };
  };

  # Order the *arr apps after Transmission so their startup health-checks
  # don't see a not-yet-listening download client. `After=` is ordering
  # only — not a hard requirement, so if Transmission fails for any reason
  # the *arr apps still start (just with a download-client warning).
  systemd.services.sonarr.after = ["transmission.service"];
  systemd.services.radarr.after = ["transmission.service"];
  systemd.services.lidarr.after = ["transmission.service"];

  # The `media` user/group is normally created by Nixarr's bazarr module
  # (and possibly others). On systems where that doesn't happen — e.g.
  # before bazarr is enabled — we provide a fallback declaration so the
  # systemd.tmpfiles rules in nixos-modules/nixarr.nix have a valid owner.
  # `lib.mkDefault` makes these the LOWEST-priority assignments, so any
  # module that explicitly sets a uid/gid (bazarr does, with its own
  # values) wins automatically — no eval-time conflict.
  users.groups.media = lib.mkDefault {
    gid = 989;
  };
  users.users.media = lib.mkDefault {
    isSystemUser = true;
    group = "media";
    uid = 989;
    description = "Shared owner of the media library";
  };

  nixarr.mediaUsers = ["nathan"];

  # Read access to the *arr API keys (Nixarr's <app>-api groups, already used
  # by Prowlarr/Bazarr/Recyclarr), so queues can be inspected and cleaned
  # over SSH without the keys being copied anywhere.
  users.users.nathan.extraGroups = ["lidarr-api" "sonarr-api" "radarr-api" "prowlarr-api"];

  # *arr v4 mandates an auth method. Nixarr's settings-sync asserts we've
  # set one before it will sync indexers. We're LAN-only behind a firewall,
  # so `DisabledForLocalAddresses` skips the login screen for LAN clients
  # while still requiring auth from anywhere off-LAN (defense in depth in
  # case the firewall rule ever changes).
  services.sonarr.settings.auth.required   = "DisabledForLocalAddresses";
  services.radarr.settings.auth.required   = "DisabledForLocalAddresses";
  services.lidarr.settings.auth.required   = "DisabledForLocalAddresses";
  services.prowlarr.settings.auth.required = "DisabledForLocalAddresses";

  environment.systemPackages = with pkgs; [
    rsync
    nfs-utils
    ffmpeg-full  # for testing NVENC: `ffmpeg -hwaccels` should list cuda
  ];

  # Give Jellyfin's systemd unit access to the NVIDIA device nodes so NVENC/
  # NVDEC works. After rebuild, in Jellyfin's web UI → Dashboard → Playback,
  # select "NVIDIA NVENC" — for the GTX 970M, see README.md for the exact
  # codec checkbox list (H.264 encode only, no HEVC encode, no AV1).
  #
  # `mkForce` on PrivateDevices because Nixarr also sets it; we need
  # it false to access /dev/nvidia*. If a future Nixarr version uses mkForce
  # itself, this assignment will fail loudly at eval time — bump to
  # `lib.mkOverride 40` (one priority class stronger than mkForce) if so.
  systemd.services.jellyfin.serviceConfig = {
    SupplementaryGroups = ["render" "video"];
    DeviceAllow = [
      "/dev/nvidia0 rw"
      "/dev/nvidiactl rw"
      "/dev/nvidia-modeset rw"
      "/dev/nvidia-uvm rw"
      "/dev/nvidia-uvm-tools rw"
      "/dev/dri rw"
    ];
    PrivateDevices = lib.mkForce false;
    # Some Nixarr hardening directives can also block /dev access — clear them
    # explicitly so we don't have to hunt them down later. mkForce is fine
    # here because Nixarr only sets these as plain assignments upstream.
    DevicePolicy = lib.mkForce "auto";
    PrivateMounts = lib.mkForce false;
  };

  system.stateVersion = "25.11";
}
