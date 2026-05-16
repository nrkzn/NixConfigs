{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
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
      stateDir = "/data/nixarr";
      # Do NOT auto-open service ports on the host firewall — every service
      # below relies on the per-service `openFirewall = false` default so
      # nothing is reachable from off-host without an SSH tunnel / VPN in.
      openFirewall = false;

      # WireGuard config at /etc/nixarr/wg.conf (root:root, 0400) — keep it
      # out of the Nix store. Transmission + Prowlarr ride this tunnel.
      vpn = {
        enable = true;
        wgConfFile = "/etc/nixarr/wg.conf";
        vpnTestService.enable = true;
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
  # NOTE: Nixarr's settings-sync does NOT cover quality profiles, custom
  # formats, naming schemes, or release profiles — the parts of TRaSH-Guides
  # most people associate with it. Those are still manual UI work after
  # first boot, or use Recyclarr (https://recyclarr.dev/) to push them.
  # See [README.md](../../README.md#trash-guides-followup) for the checklist.
  # --------------------------------------------------------------------------
  nixarr.prowlarr.settings-sync = {
    enable-nixarr-apps = true;  # auto-wires Prowlarr → every enabled *arr via internal API keys
  };

  # Nixarr's `transmission` shortcut auto-fills host/port/useSsl. Earlier I
  # tried to pass `category` and `directory` as fields too, but Nixarr
  # validates the schema against the *arr's API and those names aren't
  # accepted. To inspect the real schema on a running system:
  #   sudo nixarr show-radarr-schemas download_client | jq '.'
  # If you want categories, set them inside Radarr's UI under Download
  # Clients → Transmission after first boot.
  nixarr.sonarr.settings-sync.transmission.enable = true;
  nixarr.radarr.settings-sync.transmission.enable = true;

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

  # Nixarr's docs say it auto-creates the `media` user/group, but in practice
  # on this build it didn't (and our systemd.tmpfiles rules in the module
  # were trying to chown to a non-existent media:media). Declare it
  # explicitly. If a future Nixarr release starts also declaring it, we'll
  # hit a conflict-on-uid error at eval time — at that point, drop these
  # two blocks and re-rely on nixarr.mediaUsers alone.
  users.groups.media = {
    gid = 989;
  };
  users.users.media = {
    isSystemUser = true;
    group = "media";
    uid = 989;
    description = "Shared owner of the media library";
  };

  # Add nathan to the media group (nixarr.mediaUsers does this too, but
  # being explicit removes ambiguity about who's authoritative).
  users.users.nathan.extraGroups = ["media"];
  nixarr.mediaUsers = ["nathan"];

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
