{
  config,
  lib,
  ...
}: {
  options = {
    myNixOS.boot.enable = lib.mkEnableOption "systemd-boot EFI bootloader";
  };

  config = lib.mkIf config.myNixOS.boot.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 10;

    boot.kernelParams = ["quiet" "splash"];
  };
}
