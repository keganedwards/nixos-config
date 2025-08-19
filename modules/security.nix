# /modules/security.nix
{
  security = {
    # Disable the original sudo module
    sudo.enable = false;

    # Enable and configure the global behavior of sudo-rs
    sudo-rs = {
      enable = true;
      extraConfig = ''Defaults timestamp_timeout=0'';
    };

    # Your other security settings remain the same
    pam = {
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

    rtkit.enable = true;

    tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };
  };
}
