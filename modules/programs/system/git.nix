# /modules/programs/git.nix
{
  config,
  pkgs,
  username,
  fullName,
  email,
  ...
}: let
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  git-ssh-askpass = pkgs.writeShellScriptBin "git-ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec ${pkgs.sudo}/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  # == System-Level Configuration ==
  environment.systemPackages = [git-ssh-askpass];

  # == User-Level Configuration (Home Manager) ==
  home-manager.users.${username} = {
    programs.git = {
      enable = true;
      userName = fullName;
      userEmail = email;
      signing = {
        signByDefault = true;
        format = "ssh";
      };
      extraConfig.user.signingkey = config.sops.secrets."user-ssh-key".path;
    };

    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
    };

    home.sessionVariables = {
      SSH_ASKPASS = "${git-ssh-askpass}/bin/git-ssh-askpass";
    };

    home.file.".gitconfig" = {
      # This provides compatibility for tools that look for ~/.gitconfig
      text = ''
        [include]
          # --- THIS IS THE FIX ---
          # We use a standard path with a tilde (~). Git will correctly
          # expand this to the user's home directory. This avoids the
          # Nix scoping error entirely.
          path = ~/.config/git/config
      '';
    };

    home.file.".ssh/id_ed25519.pub" = {
      # The mode option was removed as it was incorrect.
      text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x ${email}";
    };
  };
}
