{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.users.enable = lib.mkEnableOption "primary user 'nathan'";
  };

  config = lib.mkIf config.myNixOS.users.enable {
    # mutableUsers = true: passwords are set with `passwd` and persist across
    # rebuilds; none live in this (public) repo. On a fresh install,
    # nixos-install prompts for root's password — then, as root, run
    # `passwd nathan` before the first login.
    users.mutableUsers = true;

    users.users.nathan = {
      isNormalUser = true;
      description = "Nathan";
      shell = pkgs.zsh;
      # SSH is key-only (see ssh.nix). One key per client machine.
      openssh.authorizedKeys.keyFiles = [
        ../keys/blackeyedesktop.pub
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "audio"
        "input"
        "render"
      ];
    };
  };
}
