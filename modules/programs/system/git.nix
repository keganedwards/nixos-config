{
  config,
  pkgs,
  username,
  fullName,
  email,
  ...
}: let
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  # Create an askpass script
  ssh-askpass = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  environment.systemPackages = [ssh-askpass];

  home-manager.users.${username} = {
    programs.git = {
      enable = true;
      userName = fullName;
      userEmail = email;
      signing = {
        signByDefault = true;
        format = "ssh";
      };
      extraConfig = {
        user.signingkey = "~/.ssh/id_ed25519.pub";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      };
    };

    programs.ssh = {
      enable = true;
      addKeysToAgent = "no";
      extraConfig = ''
        ForwardAgent no
        IdentityAgent none
      '';
    };

    # Set SSH_ASKPASS in the user's environment
    home.sessionVariables = {
      SSH_ASKPASS = "${ssh-askpass}/bin/ssh-askpass";
      SSH_ASKPASS_REQUIRE = "force";
    };

    home.file.".ssh/id_ed25519.pub" = {
      text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x ${email}";
    };

    home.file.".ssh/allowed_signers" = {
      text = "${email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x";
    };
  };
}
