{
  config,
  pkgs,
  ...
}: let
  library = "${config.myNixOS.nixarr.mediaDir}/library/music";

  music-genres = pkgs.writers.writePython3Bin "music-genres" {
    libraries = [pkgs.python3Packages.mutagen];
    flakeIgnore = ["E501" "W503"];
  } (builtins.readFile ./music-genres.py);
in {
  # --------------------------------------------------------------------------
  # Music tag normalization (see music-genres.py): one genre per album and no
  # stray ALBUM ARTIST/ARTISTS fields. Lidarr writes tags only on import
  # ("new files only"); this runs nightly so new albums get normalized too.
  # Run by hand: `sudo systemctl start music-genres`, preview with
  # `music-genres --dry-run`.
  # --------------------------------------------------------------------------
  environment.systemPackages = [music-genres];

  systemd.services.music-genres = {
    description = "Normalize music library genres and artist tags";
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "media";
      ExecStart = "${music-genres}/bin/music-genres ${library}";
      Nice = 19;
      IOSchedulingClass = "idle";
      ProtectSystem = "strict";
      ReadWritePaths = [library];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  systemd.timers.music-genres = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
    };
  };
}
