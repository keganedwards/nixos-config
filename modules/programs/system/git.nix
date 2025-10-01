# /modules/programs/system/git.nix
{
  config,
  pkgs,
  username,
  fullName,
  email,
  flakeDir,
  ...
}: let
  protectedUsername = "protect-${username}";
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  githubHostKeys = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
  '';

  ssh-askpass = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  # Install ssh-askpass system-wide
  environment.systemPackages = [ssh-askpass];

  # Protected user manages all configurations
  home-manager.users.${protectedUsername} = {
    # Essential environment configuration
    home.file.".config/environment.d/ssh-askpass.conf".text = ''
      SSH_ASKPASS=${ssh-askpass}/bin/ssh-askpass
      SSH_ASKPASS_REQUIRE=force
      DISPLAY=:0
    '';

    # Set in fish shell
    programs.fish.shellInit = ''
      # SSH askpass settings
      set -gx SSH_ASKPASS "${ssh-askpass}/bin/ssh-askpass"
      set -gx SSH_ASKPASS_REQUIRE force
      set -q DISPLAY; or set -gx DISPLAY :0
    '';

    home.file = {
      ".ssh/id_ed25519.pub" = {
        text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x ${email}";
      };
      ".ssh/allowed_signers" = {
        text = "${email} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x";
      };
      # Add known_hosts file with GitHub's host keys
      ".ssh/known_hosts" = {
        text = githubHostKeys;
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
          core.sshCommand = "ssh";

          safe.directory = [
            "/home/${username}/nixos-config"
            "/home/${username}/.dotfiles"
          ];
        };
      };

      ssh = {
        enable = true;

        # Explicitly disable default config to suppress the warning
        enableDefaultConfig = false;

        # Define all our configuration in matchBlocks
        matchBlocks = {
          # Global defaults (equivalent to Host *)
          "*" = {
            # Disable agent forwarding for security
            forwardAgent = false;
            # Don't add keys to agent
            extraOptions = {
              AddKeysToAgent = "no";
              # Disable connection sharing
              ControlMaster = "no";
              ControlPath = "none";
              ControlPersist = "no";
              # Basic settings
              Compression = "no";
              ServerAliveInterval = "60";
              ServerAliveCountMax = "3";
              # Don't hash known hosts since we're managing them explicitly
              HashKnownHosts = "no";
              # Use only the specific identity file
              IdentitiesOnly = "yes";
              # Single password attempt
              NumberOfPasswordPrompts = "1";
              PreferredAuthentications = "publickey";
              PubkeyAuthentication = "yes";
              PasswordAuthentication = "no";
              # Strict host key checking
              StrictHostKeyChecking = "yes";
              UserKnownHostsFile = "~/.ssh/known_hosts";
            };
          };

          # GitHub specific configuration
          "github.com" = {
            hostname = "github.com";
            user = "git";
            identityFile = "~/.ssh/id_ed25519";
            identitiesOnly = true;
            extraOptions = {
              PreferredAuthentications = "publickey";
            };
          };
        };
      };
    };
  };

  home-manager.users.root = {
    home.stateVersion = config.home-manager.users.${username}.home.stateVersion;

    # Configure git for root
    programs.git = {
      enable = true;
      userName = fullName;
      userEmail = email;
      extraConfig = {
        safe.directory = [
          flakeDir
          "/home/${username}/.dotfiles"
        ];
        user = {
          signingkey = "/home/${username}/.ssh/id_ed25519.pub";
        };
        gpg = {
          format = "ssh";
          ssh = {
            allowedSignersFile = "/home/${username}/.ssh/allowed_signers";
            program = "${pkgs.openssh}/bin/ssh-keygen";
          };
        };
        commit.gpgsign = true;
        core.sshCommand = "${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519";
      };
    };

    # Add GitHub's known host keys for root
    home.file.".ssh/known_hosts" = {
      text = ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
      '';
    };
  };

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      git
      openssh
    ];
  };
}
