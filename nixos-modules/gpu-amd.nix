{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    myNixOS.gpu.amd.enable = lib.mkEnableOption "AMD GPU stack (Mesa, ROCm)";
  };

  config = lib.mkIf config.myNixOS.gpu.amd.enable {
    # Force amdgpu (in-kernel since 4.15); avoids X11 servers trying radeon.
    boot.initrd.kernelModules = ["amdgpu"];
    services.xserver.videoDrivers = lib.mkDefault ["amdgpu"];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
        amdvlk
        libva
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        amdvlk
      ];
    };

    environment.sessionVariables = {
      AMD_VULKAN_ICD = "RADV";  # Mesa's open Vulkan, generally faster than amdvlk
    };
  };
}
