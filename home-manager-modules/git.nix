{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myHomeManager.git = {
      enable = lib.mkEnableOption "git config";
      userName = lib.mkOption {
        type = lib.types.str;
        default = "Nathan";
      };
      userEmail = lib.mkOption {
        type = lib.types.str;
        default = "nathan.kozian@proton.me";
      };
    };
  };

  config = lib.mkIf config.myHomeManager.git.enable {
    programs.git = {
      enable = true;
      userName = config.myHomeManager.git.userName;
      userEmail = config.myHomeManager.git.userEmail;
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
      };
      aliases = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --oneline --graph --decorate --all";
      };
    };

    programs.gh = {
      enable = true;
      settings.git_protocol = "ssh";
    };
  };
}
