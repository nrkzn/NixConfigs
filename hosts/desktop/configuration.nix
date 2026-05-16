{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  myNixOS = {
    core.enable = true;
    boot.enable = true;
    users.enable = true;
    audio.enable = true;
    bluetooth.enable = true;
    fonts.enable = true;
    hyprland.enable = true;
    gaming.enable = true;
    ssh.enable = true;

    networking = {
      enable = true;
      hostName = "desktop";
    };

    # Pick the GPU module that matches your hardware; both default off.
    gpu.nvidia.enable = false;
    gpu.amd.enable = true;

    virtualisation = {
      docker.enable = true;
      libvirt.enable = false;
    };
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    firefox
    kitty
  ];

  system.stateVersion = "25.11";
}
