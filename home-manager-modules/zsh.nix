{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myHomeManager.zsh.enable = lib.mkEnableOption "zsh with starship, oh-my-zsh-style aliases, fzf";
  };

  config = lib.mkIf config.myHomeManager.zsh.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      historySubstringSearch.enable = true;

      shellAliases = {
        ll = "eza -la --icons --git";
        ls = "eza --icons";
        la = "eza -a --icons";
        lt = "eza --tree --icons";
        cat = "bat";
        cd = "z";
        rebuild = "sudo nixos-rebuild switch --flake .";
        update = "nix flake update";
        gc = "sudo nix-collect-garbage -d";
      };

      history = {
        size = 10000;
        save = 10000;
        ignoreDups = true;
        share = true;
      };
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        format = lib.concatStrings [
          "$username"
          "$hostname"
          "$directory"
          "$git_branch"
          "$git_status"
          "$nix_shell"
          "$line_break"
          "$character"
        ];
      };
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
