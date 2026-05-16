{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.myNixOS.gpu.nvidia;
in {
  options.myNixOS.gpu.nvidia = {
    enable = lib.mkEnableOption "proprietary NVIDIA driver";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Headless mode: install the NVIDIA kernel module + NVENC/NVDEC/VAAPI
        userspace for compute and video transcoding, but skip the X video
        driver, nvidia-settings, and Wayland session variables. Use this on
        servers (e.g. for Jellyfin hardware transcoding).
      '';
    };

    open = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use the open-source NVIDIA kernel modules (Turing+ only).";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "NVIDIA driver package. Null = stable from current kernel.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # ----- shared (desktop + headless) -----
    {
      hardware.graphics = {
        enable = true;
        enable32Bit = !cfg.headless;
        extraPackages = with pkgs;
          [
            nvidia-vaapi-driver
            libvdpau-va-gl
            libva-vdpau-driver
          ]
          ++ lib.optionals (!cfg.headless) [
            vulkan-loader
            vulkan-validation-layers
          ];
      };

      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        open = cfg.open;
        nvidiaSettings = !cfg.headless;
        package =
          if cfg.package != null
          then cfg.package
          else config.boot.kernelPackages.nvidiaPackages.stable;
      };

      # nvidia-smi etc. are useful everywhere
      environment.systemPackages = with pkgs; [
        libva-utils
        vdpauinfo
      ];
    }

    # ----- desktop only -----
    (lib.mkIf (!cfg.headless) {
      services.xserver.videoDrivers = ["nvidia"];

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })

    # ----- headless / transcoding only -----
    (lib.mkIf cfg.headless {
      # Load nvidia + nvidia_uvm at boot without pulling in X
      boot.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

      # Persistence daemon keeps the driver warm so the first transcode isn't slow
      hardware.nvidia.nvidiaPersistenced = true;

      # Make sure /dev/nvidia* exist on boot, not just when something opens them
      services.udev.extraRules = ''
        KERNEL=="nvidia", RUN+="${pkgs.coreutils}/bin/chmod 0666 /dev/nvidia*"
        KERNEL=="nvidia_uvm", RUN+="${pkgs.coreutils}/bin/chmod 0666 /dev/nvidia-uvm*"
      '';

      environment.systemPackages = with pkgs; [
        nvtopPackages.nvidia
      ];
    })
  ]);
}
