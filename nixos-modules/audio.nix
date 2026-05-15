{
  config,
  lib,
  ...
}: {
  options = {
    myNixOS.audio.enable = lib.mkEnableOption "PipeWire audio stack";
  };

  config = lib.mkIf config.myNixOS.audio.enable {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };
  };
}
