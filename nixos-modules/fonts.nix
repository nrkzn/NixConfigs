{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.fonts.enable = lib.mkEnableOption "system font set (Nerd Fonts, Noto, JetBrains Mono)";
  };

  config = lib.mkIf config.myNixOS.fonts.enable {
    fonts = {
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-emoji
        liberation_ttf
        jetbrains-mono
        fira-code
        fira-code-symbols
        font-awesome
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        nerd-fonts.symbols-only
      ];

      fontconfig = {
        defaultFonts = {
          serif = ["Noto Serif"];
          sansSerif = ["Noto Sans"];
          monospace = ["JetBrainsMono Nerd Font"];
          emoji = ["Noto Color Emoji"];
        };
      };
    };
  };
}
