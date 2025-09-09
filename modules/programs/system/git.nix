# /modules/programs/system/git.nix
{
  config,
  pkgs,
  username,
  fullName,
  email,
  ...
}: let
  protectedUsername = "protect-${username}";
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  # Create ssh-askpass in /run/wrappers equivalent location
  ssh-askpass = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  # Install ssh-askpass system-wide in a protected location
  environment.systemPackages = [ssh-askpass];

  # Protected user manages all configurations
  home-manager.users.${protectedUsername} = {
    # Essential environment configuration
    home.file.".config/environment.d/ssh-askpass.conf".text = ''
      SSH_ASKPASS=${ssh-askpass}/bin/ssh-askpass
      SSH_ASKPASS_REQUIRE=force
    '';

    # Set SSH askpass in fish shell via shellInit
    programs.fish.shellInit = ''
      # Override SSH askpass settings with our secure version
      set -gx SSH_ASKPASS "${ssh-askpass}/bin/ssh-askpass"
      set -gx SSH_ASKPASS_REQUIRE force
    '';

    home.file = {
      ".ssh/id_ed25519.pub" = {
        text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x ${email}";
      };
      ".ssh/allowed_signers" = {
        text = "${email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x";
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
          core.sshCommand = "ssh -o SendEnv='SSH_ASKPASS SSH_ASKPASS_REQUIRE'";
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
          sendEnv = ["LANG" "LC_*" "SSH_ASKPASS" "SSH_ASKPASS_REQUIRE"];
        };
      };
    };
  };

  # Main user only gets the packages
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      git
      openssh
    ];
  };
}
