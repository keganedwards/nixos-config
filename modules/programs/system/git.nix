{
  config,
  pkgs,
  username,
  fullName,
  email,
  ...
}: let
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  # A simple script that uses the standard, secure sudo wrapper.
  ssh-askpass = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  home-manager.users.${username} = {
    home.packages = [ssh-askpass];

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
        init.defaultBranch = "main";
      };
    };

    programs.ssh.enable = true;

    # This is the definitive fix for the email identity problem.
    # It uses the input variables instead of hardcoded strings.
    home.sessionVariables = {
      GIT_AUTHOR_NAME = fullName;
      GIT_AUTHOR_EMAIL = email;
      GIT_COMMITTER_NAME = fullName;
      GIT_COMMITTER_EMAIL = email;

      # These variables enable the automatic password prompt for signing.
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
