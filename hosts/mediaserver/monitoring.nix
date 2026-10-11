{
  config,
  lib,
  pkgs,
  ...
}: let
  exp = config.services.prometheus.exporters;
  arr = config.nixarr;

  # Scrape jobs: name → local port. Everything listens on 127.0.0.1 except
  # the WireGuard exporter, which Nixarr runs inside the VPN namespace and
  # proxies to the host (blocked off-host by the firewall).
  jobs = {
    prometheus = config.services.prometheus.port;
    node = exp.node.port;
    systemd = exp.systemd.port;
    nvidia-gpu = exp.nvidia-gpu.port;
    sonarr = arr.sonarr.exporter.port;
    radarr = arr.radarr.exporter.port;
    lidarr = arr.lidarr.exporter.port;
    prowlarr = arr.prowlarr.exporter.port;
    wireguard = arr.wireguard.exporter.port;
  };

  # Community dashboards from grafana.com, pinned by revision + hash. Some
  # were exported with a `${DS_…}` datasource placeholder, which file
  # provisioning doesn't resolve — point those at our datasource uid.
  dashboard = {
    id,
    rev,
    hash,
    dsPlaceholder ? null,
  }: let
    src = pkgs.fetchurl {
      name = "grafana-dashboard-${toString id}-r${toString rev}.json";
      url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString rev}/download";
      inherit hash;
    };
  in
    if dsPlaceholder == null
    then src
    else
      pkgs.runCommand "grafana-dashboard-${toString id}.json" {} ''
        sed 's/[$]{${dsPlaceholder}}/prometheus/g' ${src} > $out
      '';

  dashboards = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "node-exporter-full.json";
      path = dashboard {
        id = 1860;
        rev = 45;
        hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
      };
    }
    {
      name = "sonarr.json";
      path = dashboard {
        id = 12530;
        rev = 2;
        hash = "sha256-SRAc9g9Xo06eBmUUzIX7ETBhvfMTTt3f1NSC5/ehFls=";
        dsPlaceholder = "DS_PROMETHEUS";
      };
    }
    {
      name = "radarr.json";
      path = dashboard {
        id = 12896;
        rev = 1;
        hash = "sha256-MGLFgQhMoCB6hD/uci+NfN6q4tssWbsfqINpQsrlF7s=";
        dsPlaceholder = "DS_RANCHER_MONITORING";
      };
    }
  ];
in {
  # --------------------------------------------------------------------------
  # Monitoring: exporters → Prometheus (store, 30 days) → Grafana (view).
  # Grafana: http://holodeck:3000 — LAN only (firewall rule in
  # configuration.nix), deliberately NOT routed through the Cloudflare tunnel.
  # Login: admin / password in secrets/mediaserver.yaml
  # (`grafana-admin-password`).
  # --------------------------------------------------------------------------

  # Exporters. Nixarr enables exportarr (Sonarr/Radarr/Lidarr/Prowlarr),
  # node, systemd and WireGuard; here they're pinned to localhost.
  nixarr.exporters.enable = true;
  nixarr.sonarr.exporter.listenAddr = "127.0.0.1";
  nixarr.radarr.exporter.listenAddr = "127.0.0.1";
  nixarr.lidarr.exporter.listenAddr = "127.0.0.1";
  nixarr.prowlarr.exporter.listenAddr = "127.0.0.1";

  services.prometheus.exporters = {
    node.listenAddress = "127.0.0.1";
    systemd.listenAddress = "127.0.0.1";
    # GPU load / memory / temperature during Jellyfin NVENC transcodes.
    nvidia-gpu = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    retentionTime = "30d";
    globalConfig.scrape_interval = "30s";
    scrapeConfigs =
      lib.mapAttrsToList (name: port: {
        job_name = name;
        static_configs = [{targets = ["127.0.0.1:${toString port}"];}];
      })
      jobs;
  };

  sops.secrets = {
    grafana-admin-password = {
      owner = "grafana";
      restartUnits = ["grafana.service"];
    };
    grafana-secret-key = {
      owner = "grafana";
      restartUnits = ["grafana.service"];
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      security = {
        admin_user = "admin";
        # Only applied when Grafana creates its database (first start);
        # change it later in the UI.
        admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
        secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
      };
      users.allow_sign_up = false;
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          # name and uid both "prometheus" so dashboards referencing the
          # datasource either way resolve to it.
          name = "prometheus";
          uid = "prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "holodeck";
          options.path = dashboards;
        }
      ];
    };
  };
}
