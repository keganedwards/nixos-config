# /modules/system/security.nix
{...}: {
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

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout = 0
  '';

  security.rtkit.enable = true;
  security.polkit.enable = true;

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
}
