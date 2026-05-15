{
  description = "Nathan's NixOS flake — desktop (Hyprland) + mediaserver (Nixarr), Vimjoyer-style layout";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pin to a tagged release. v0.55 (May 2026) switched config to Lua, which
    # breaks the `settings = { … }` attrset in our Hyprland HM module — stay
    # on v0.53 until that module is rewritten.
    hyprland.url = "github:hyprwm/Hyprland?ref=v0.53.0";

    nixarr.url = "github:rasmus-kirk/nixarr";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    hyprland,
    nixarr,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # Vimjoyer's helper: recursively import every .nix file in a directory
    # as a list of modules. Skips default.nix to avoid double-imports.
    importModules = dir:
      let
        entries = builtins.readDir dir;
        toPath = name: dir + "/${name}";
        isNixFile = name: type:
          type == "regular"
          && nixpkgs.lib.hasSuffix ".nix" name
          && name != "default.nix";
        isDir = name: type: type == "directory";
        nixFiles = builtins.attrNames (nixpkgs.lib.filterAttrs isNixFile entries);
        subdirs = builtins.attrNames (nixpkgs.lib.filterAttrs isDir entries);
      in
        (map toPath nixFiles)
        ++ (builtins.concatLists (map (d: importModules (toPath d)) subdirs));

    nixosModules = importModules ./nixos-modules;
    homeManagerModules = importModules ./home-manager-modules;
  in {
    # Expose modules so other flakes (or `nix flake show`) can see them
    nixosModules.default = {
      imports = nixosModules;
    };
    homeManagerModules.default = {
      imports = homeManagerModules;
    };

    nixosConfigurations = {
      desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          nixosModules
          ++ [
            ./hosts/desktop/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs;};
              home-manager.users.nathan = {
                imports =
                  homeManagerModules
                  ++ [./hosts/desktop/home.nix];
              };
            }
          ];
      };

      mediaserver = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          nixosModules
          ++ [
            ./hosts/mediaserver/configuration.nix
            nixarr.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {inherit inputs;};
              home-manager.users.nathan = {
                imports =
                  homeManagerModules
                  ++ [./hosts/mediaserver/home.nix];
              };
            }
          ];
      };
    };

    # Standalone home configs (optional, for `home-manager switch --flake .#user@host`)
    homeConfigurations = {
      "nathan@desktop" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit inputs;};
        modules =
          homeManagerModules
          ++ [./hosts/desktop/home.nix];
      };
      "nathan@mediaserver" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit inputs;};
        modules =
          homeManagerModules
          ++ [./hosts/mediaserver/home.nix];
      };
    };

    formatter.${system} = pkgs.alejandra;
  };
}
