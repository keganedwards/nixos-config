# /modules/programs/system/git.nix
{
  config,
  pkgs,
  username,
  fullName,
  email,
  ...
}: let
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  ssh-askpass = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  home-manager.users.${username} = {
    home = {
      packages = [ssh-askpass];

      sessionVariables = {
        GIT_AUTHOR_NAME = fullName;
        GIT_AUTHOR_EMAIL = email;
        GIT_COMMITTER_NAME = fullName;
        GIT_COMMITTER_EMAIL = email;

        SSH_ASKPASS = "${ssh-askpass}/bin/ssh-askpass";
        SSH_ASKPASS_REQUIRE = "force";
      };

      file = {
        ".ssh/id_ed25519.pub" = {
          text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x ${email}";
        };
        ".ssh/allowed_signers" = {
          text = "${email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x";
        };
      };
    };

    programs = {
      git = {
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

      ssh = {
        enable = true;
        enableDefaultConfig = false;

        matchBlocks."*" = {
          forwardAgent = false;
          addKeysToAgent = "no";
          controlMaster = "no";
          controlPath = "none";
          controlPersist = "no";

          compression = false;
          serverAliveInterval = 0;
          serverAliveCountMax = 3;
          hashKnownHosts = true;
          userKnownHostsFile = "~/.ssh/known_hosts";
          identitiesOnly = true;
          # --- CORRECTED LINE ---
          sendEnv = ["LANG" "LC_*"];
          # ----------------------
        };
      };
    };
  };
}
