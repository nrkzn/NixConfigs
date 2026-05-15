{
  config,
  lib,
  ...
}: {
  options = {
    myHomeManager.firefox.enable = lib.mkEnableOption "Firefox browser";
  };

  config = lib.mkIf config.myHomeManager.firefox.enable {
    programs.firefox = {
      enable = true;
      profiles.default = {
        id = 0;
        isDefault = true;
        settings = {
          "browser.startup.homepage" = "about:home";
          "browser.aboutConfig.showWarning" = false;
          "browser.toolbars.bookmarks.visibility" = "always";
          "signon.rememberSignons" = false;
          "media.ffmpeg.vaapi.enabled" = true;
          "gfx.webrender.all" = true;
        };
      };
    };
  };
}
