{config, ...}: let
  arr = config.myNixOS.nixarr;

  # TRaSH-Guides quality profile trash IDs (German variants).
  profiles = {
    radarr = {
      german = "2b90e905c99490edc7c7a5787443748b"; # [German] HD Bluray + WEB
      germanAnime = "bf3cc2e99ad9a804a9b0d0e538e1fbba"; # [German] Anime HD Bluray + WEB
    };
    sonarr = {
      german = "dca7e5e9e99c703bcbdaaa471dd40e98"; # [German] HD Bluray + WEB
      germanAnime = "6fe5937e1dcc2269e23b49eb46dfe6d6"; # [German] Anime HD Bluray + WEB
    };
  };

  assignTo = ids: map (id: {trash_id = id;}) ids;
in {
  # --------------------------------------------------------------------------
  # TRaSH-Guides quality profiles, custom formats, quality sizes and naming
  # for Sonarr + Radarr, synced daily by Recyclarr (v8 config schema).
  #
  # Language goal: German dub AND the original-language track (English for
  # English shows, Japanese for anime). TRaSH's German profiles score that
  # directly via their language custom formats:
  #   German DL  (German + original audio)  +11000  ← preferred
  #   German     (German audio only)        +10000
  #   original only (no German)                  0  ← grabbed if nothing
  #                                                  better, then upgraded
  #   Not German / original / English      −35000  ← effectively blocked
  # Cutoff is 35000, so the *arrs keep upgrading towards a German DL release.
  #
  # Mirrors recyclarr/config-templates german-hd-bluray-web and
  # german-anime-hd-bluray-web. Pick the Anime profile for anime (Seerr has a
  # separate "Anime Quality Profile" setting for Sonarr).
  #
  # 1080p on purpose: the GTX 970M can't transcode HEVC, and "Golden Rule HD"
  # penalises x265 for HD releases so Jellyfin can direct-play or
  # NVENC-transcode H.264. (Anime is often 10-bit x265 regardless — that
  # falls back to CPU transcoding if a client can't direct-play it.)
  #
  # API keys: Nixarr's recyclarr-setup service reads the *arr-generated keys
  # from ${stateDir}/secrets/ and exposes them as env vars, referenced below
  # with `!env_var`. Nothing secret lives in this file.
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
            trash_id = profiles.radarr.german;
            reset_unmatched_scores.enabled = true;
          }
          {
            trash_id = profiles.radarr.germanAnime;
            reset_unmatched_scores.enabled = true;
          }
        ];

        custom_format_groups.add = [
          {
            trash_id = "f8bf8eab4617f12dfdbd16303d8da245"; # [Optional] Golden Rule HD
            assign_scores_to = assignTo [profiles.radarr.german];
          }
          {
            trash_id = "0ca61b4b233178d07113082a7acff72d"; # [Unwanted] Unwanted Formats German
            assign_scores_to = assignTo [profiles.radarr.german profiles.radarr.germanAnime];
          }
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
            trash_id = profiles.sonarr.german;
            reset_unmatched_scores.enabled = true;
          }
          {
            trash_id = profiles.sonarr.germanAnime;
            reset_unmatched_scores.enabled = true;
          }
        ];

        custom_format_groups.add = [
          {
            trash_id = "158188097a58d7687dee647e04af0da3"; # [Optional] Golden Rule HD
            assign_scores_to = assignTo [profiles.sonarr.german profiles.sonarr.germanAnime];
          }
          {
            trash_id = "6f0872eebfc95b1f93474b7ac866ced0"; # [Unwanted] Unwanted Formats German
            assign_scores_to = assignTo [profiles.sonarr.german profiles.sonarr.germanAnime];
          }
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
