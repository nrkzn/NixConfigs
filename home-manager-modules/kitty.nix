{
  config,
  lib,
  ...
}: {
  options = {
    myHomeManager.kitty.enable = lib.mkEnableOption "kitty terminal";
  };

  config = lib.mkIf config.myHomeManager.kitty.enable {
    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };
      themeFile = "GruvboxDark";
      settings = {
        scrollback_lines = 10000;
        enable_audio_bell = false;
        confirm_os_window_close = 0;
        window_padding_width = 8;
        background_opacity = "0.92";
        cursor_shape = "beam";
        cursor_blink_interval = 0;
        tab_bar_style = "powerline";
      };
      keybindings = {
        "ctrl+shift+enter" = "new_window";
        "ctrl+shift+t" = "new_tab";
      };
    };
  };
}
