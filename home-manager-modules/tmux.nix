{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myHomeManager.tmux.enable = lib.mkEnableOption "tmux terminal multiplexer";
  };

  config = lib.mkIf config.myHomeManager.tmux.enable {
    programs.tmux = {
      enable = true;
      shortcut = "a";
      baseIndex = 1;
      escapeTime = 10;
      keyMode = "vi";
      mouse = true;
      terminal = "tmux-256color";
      historyLimit = 50000;

      plugins = with pkgs.tmuxPlugins; [
        sensible
        yank
        resurrect
        continuum
      ];

      extraConfig = ''
        set -g status-style "bg=#282828,fg=#ebdbb2"
        set -g status-left "#[fg=#fabd2f,bold] #S "
        set -g status-right "#[fg=#a89984] %Y-%m-%d %H:%M "
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
      '';
    };
  };
}
