{
  config,
  lib,
  ...
}: {
  options = {
    myNixOS.ssh.enable = lib.mkEnableOption "OpenSSH server (key-only auth)";
  };

  config = lib.mkIf config.myNixOS.ssh.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
      openFirewall = true;
    };
  };
}
