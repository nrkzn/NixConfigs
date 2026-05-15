{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
# PLACEHOLDER — replace with the file generated on the target machine:
#   sudo nixos-generate-config --show-hardware-config > hosts/mediaserver/hardware-configuration.nix
#
# The assertion below makes `nixos-rebuild` fail loudly if you forget. To
# silence it on the real target, delete the assertion AND replace the
# placeholder fileSystems/kernelModules below with the generated values.
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  assertions = [{
    assertion = false;
    message = ''
      hosts/mediaserver/hardware-configuration.nix is still the placeholder.
      On the target machine run:
        sudo nixos-generate-config --show-hardware-config \
          > hosts/mediaserver/hardware-configuration.nix
      and delete the `assertions` block from the resulting file.
    '';
  }];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  # Replace with the real device for your media drive.
  # fileSystems."/data" = {
  #   device = "/dev/disk/by-label/data";
  #   fsType = "ext4";
  # };

  swapDevices = [];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
