{config, ...}: let
  arr = config.myNixOS.nixarr;
in {
  # --------------------------------------------------------------------------
  # TRaSH-Guides quality profiles, custom formats, quality sizes and naming
  # for Sonarr + Radarr, synced daily by Recyclarr (v8 config schema).
  #
  # Mirrors recyclarr/config-templates:
  #   radarr  hd-bluray-web  → "HD Bluray + WEB" (1080p, Bluray preferred)
  #   sonarr  web-1080p      → "WEB-1080p"
  # Trash IDs are stable identifiers from the TRaSH-Guides JSON; comments name
  # what each one is. Browse alternatives with `recyclarr list` on the server.
  #
  # 1080p on purpose: the GTX 970M can't transcode HEVC, and "Golden Rule HD"
  # (kept at its default) penalises x265 for HD releases so Jellyfin can
  # direct-play or NVENC-transcode H.264 instead of falling back to the CPU.
  #
  # API keys: Nixarr's recyclarr-setup service reads the *arr-generated keys
  # from ${stateDir}/secrets/ and exposes them as env vars, referenced below
  # with `!env_var`. Nothing secret lives in this file.
  #
  # Not covered by Recyclarr (still UI work, see README): root folders,
  # picking the synced profile as default, Lidarr (no Recyclarr support).
  # --------------------------------------------------------------------------
  nixarr.recyclarr = {
    enable = true;
    schedule = "daily";

    configuration = {
      radarr.movies = {
        base_url = "http://127.0.0.1:${toString arr.radarr.port}";
        api_key = "!env_var RADARR_API_KEY";

        quality_definition.type = "movie";

        quality_profiles = [
          {
            trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
            reset_unmatched_scores.enabled = true;
          }
        ];

        custom_format_groups.add = [
          {trash_id = "f8bf8eab4617f12dfdbd16303d8da245";} # [Optional] Golden Rule HD
          {trash_id = "a3ac6af01d78e4f21fcb75f601ac96df";} # [Unwanted] Unwanted Formats
        ];

        # TRaSH's Jellyfin naming: "Movie (Year) [tmdbid-123]" folders/files,
        # which Jellyfin matches without guessing.
        media_naming = {
          folder = "jellyfin-tmdb";
          movie = {
            rename = true;
            standard = "jellyfin-tmdb";
          };
        };
      };

      sonarr.series = {
        base_url = "http://127.0.0.1:${toString arr.sonarr.port}";
        api_key = "!env_var SONARR_API_KEY";

        quality_definition.type = "series";

        quality_profiles = [
          {
            trash_id = "72dae194fc92bf828f32cde7744e51a1"; # WEB-1080p
            reset_unmatched_scores.enabled = true;
          }
        ];

        custom_format_groups.add = [
          {trash_id = "158188097a58d7687dee647e04af0da3";} # [Optional] Golden Rule HD
          {trash_id = "74aff4168620ed49dcc67e92b2c2a5b4";} # [Optional] Language Profiles
          {trash_id = "85fae4a2294965b75710ef2989c850eb";} # [Streaming Services] HD/UHD boost
          {trash_id = "59c3af66780d08332fdc64e68297098f";} # [Unwanted] Unwanted Formats
        ];

        media_naming = {
          series = "jellyfin-tvdb";
          season = "default";
          episodes = {
            rename = true;
            standard = "default";
            daily = "default";
            anime = "default";
          };
        };
      };
    };
  };
}
