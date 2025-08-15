# /modules/security.nix
{
  # Disable the original sudo module
  security.sudo.enable = false;

  # Enable and configure the global behavior of sudo-rs
  security.sudo-rs = {
    enable = true;
    extraConfig = ''Defaults timestamp_timeout=0'';
  };

  # Your other security settings remain the same
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

  security.rtkit.enable = true;

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
}
