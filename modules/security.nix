{
  security = {
    apparmor.enable = true;

    sudo-rs = {
      enable = true;
      wheelNeedsPassword = true;
      extraConfig = ''
        Defaults timestamp_timeout=0
        Defaults passwd_tries=999
        Defaults passwd_timeout=0
      '';
    };

    pam.loginLimits = [
      {
        domain = "@users";
        item = "rtprio";
        type = "-";
        value = 1;
      }
    ];

    rtkit.enable = true;

    tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };
  };
}
