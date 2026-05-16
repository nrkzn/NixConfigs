{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.core.enable = lib.mkEnableOption "core baseline (nix settings, locale, time, common pkgs)";
  };

  config = lib.mkIf config.myNixOS.core.enable {
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "@wheel"];
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    nixpkgs.config.allowUnfree = true;

    time.timeZone = lib.mkDefault "America/New_York";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    environment.systemPackages = with pkgs; [
      git
      vim
      wget
      curl
      htop
      btop
      tree
      unzip
      pciutils
      usbutils
      file
      jq
      ripgrep
      fd
    ];

    programs.zsh.enable = true;
    environment.shells = with pkgs; [zsh bash];

    system.stateVersion = lib.mkDefault "25.11";
  };
}
