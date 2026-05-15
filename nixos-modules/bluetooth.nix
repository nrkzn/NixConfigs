{
  config,
  lib,
  ...
}: {
  options = {
    myNixOS.bluetooth.enable = lib.mkEnableOption "Bluetooth via bluez + blueman";
  };

  config = lib.mkIf config.myNixOS.bluetooth.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Experimental = true;
    };
    services.blueman.enable = true;
  };
}
