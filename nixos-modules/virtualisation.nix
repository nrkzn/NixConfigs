{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.virtualisation = {
      docker.enable = lib.mkEnableOption "Docker daemon";
      libvirt.enable = lib.mkEnableOption "libvirtd + virt-manager";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.myNixOS.virtualisation.docker.enable {
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
      users.users.nathan.extraGroups = ["docker"];
    })

    (lib.mkIf config.myNixOS.virtualisation.libvirt.enable {
      virtualisation.libvirtd.enable = true;
      programs.virt-manager.enable = true;
      users.users.nathan.extraGroups = ["libvirtd"];
    })
  ];
}
