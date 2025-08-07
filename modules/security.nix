# /modules/system/security.nix
{ pkgs, ... }: {
  security.pam = {
    loginLimits = [
      {
        domain = "@users";
        item = "rtprio";
        type = "-";
        value = 1;
      }
    ];
    services.swaylock = {};
  };

  # This sudo configuration is correct and remains unchanged.
  # It enables per-terminal, non-expiring authentication tickets.
  security.sudo.extraConfig = ''
    Defaults tty_tickets
    Defaults timestamp_timeout=-1
  '';

  security.rtkit.enable = true;

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
}
