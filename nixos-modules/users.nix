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
    # mutableUsers = true (default) means passwords set with `passwd` persist
    # across rebuilds. `initialPassword` only applies on the *first* boot
    # where the user doesn't already have a password set; after the first
    # `passwd nathan` (or `passwd root`) the value here is ignored.
    #
    # First-boot drill:
    #   1. Log in with "changeme" as the password.
    #   2. Run `passwd` immediately to set a real password.
    #   3. (Optional) Remove the initialPassword lines from this module
    #      and rebuild — at that point the live password is what sticks.
    users.mutableUsers = true;

    users.users.root.initialPassword = "changeme";

    users.users.nathan = {
      isNormalUser = true;
      description = "Nathan";
      shell = pkgs.zsh;
      initialPassword = "changeme";
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
