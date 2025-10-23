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

  sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x";

  githubHostKeys = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk= # ripsecrets-ignore
  '';

  ssh-askpass = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  # Install ssh-askpass system-wide
  environment.systemPackages = [ssh-askpass];

  # FIX: Combine all home-manager configurations into a single block
  home-manager = {
    users = {
      # Protected user manages all configurations
      ${protectedUsername} = {
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
            text = "${sshPublicKey} ${email}";
          };
          ".ssh/allowed_signers" = {
            text = "${email} ${sshPublicKey}";
          };
          ".ssh/known_hosts" = {
            text = githubHostKeys;
          };
        };

        programs = {
          git = {
            enable = true;
            signing = {
              signByDefault = true;
              format = "ssh";
            };
            settings = {
              user = {
                inherit fullName email;
                signingkey = "~/.ssh/id_ed25519.pub";
              };
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
            enableDefaultConfig = false;
            matchBlocks = {
              "*" = {
                forwardAgent = false;
                extraOptions = {
                  AddKeysToAgent = "no";
                  ControlMaster = "no";
                  ControlPath = "none";
                  ControlPersist = "no";
                  Compression = "no";
                  ServerAliveInterval = "60";
                  ServerAliveCountMax = "3";
                  HashKnownHosts = "no";
                  IdentitiesOnly = "yes";
                  NumberOfPasswordPrompts = "1";
                  PreferredAuthentications = "publickey";
                  PubkeyAuthentication = "yes";
                  PasswordAuthentication = "no";
                  StrictHostKeyChecking = "yes";
                  UserKnownHostsFile = "~/.ssh/known_hosts";
                };
              };
              "github.com" = {
                hostname = "github.com";
                user = "git";
                identityFile = "~/.ssh/id_ed25519";
                identitiesOnly = true;
                extraOptions.PreferredAuthentications = "publickey";
              };
            };
          };
        };
      };

      # Root user configuration
      root = {
        home.stateVersion = config.home-manager.users.${username}.home.stateVersion;
        programs.git = {
          enable = true;
          settings = {
            safe.directory = [
              flakeDir
              "/home/${username}/.dotfiles"
            ];
            user = {
              inherit fullName email;
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
        home.file.".ssh/known_hosts".text = githubHostKeys;
      };

      # Main user configuration
      ${username} = {
        home.packages = with pkgs; [
          git
          openssh
        ];
      };
    };
  };
}
