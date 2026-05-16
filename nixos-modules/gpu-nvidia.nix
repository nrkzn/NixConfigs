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
      # `services.xserver.videoDrivers = ["nvidia"]` is what actually causes
      # NixOS to build the kernel module, install nvidia-smi, blacklist
      # nouveau, etc. It is NOT optional in headless mode — it just doesn't
      # start an X session unless services.xserver.enable is true.
      services.xserver.videoDrivers = ["nvidia"];

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

      environment.systemPackages = with pkgs; [
        libva-utils
        vdpauinfo
      ];
    }

    # ----- desktop only -----
    (lib.mkIf (!cfg.headless) {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })

    # ----- headless / transcoding only -----
    (lib.mkIf cfg.headless {
      # Force-load the nvidia modules at boot regardless of X.
      boot.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

      # Belt-and-braces: explicitly blacklist nouveau in case anything tries
      # to load it before the nvidia module wins.
      boot.blacklistedKernelModules = ["nouveau"];

      # Persistence daemon keeps the driver warm so first transcode isn't slow
      hardware.nvidia.nvidiaPersistenced = true;

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
