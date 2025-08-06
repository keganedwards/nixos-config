# /modules/programs/git.nix
{
  config,
  pkgs,
  username,
  fullName,
  email,
  ...
}: let
  # Define variables once at the top level for use throughout the module.
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  git-ssh-askpass = pkgs.writeShellScriptBin "git-ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    # Securely fetches the SSH key passphrase using sudo.
    exec ${pkgs.sudo}/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';

in {
  # == System-Level Configuration ==

  # The custom security.sudo.extraConfig block has been removed to fix the build error.
  # The system will use its default, more secure sudo timeout settings.

  # Install the custom script so it's available in the system PATH.
  environment.systemPackages = [ git-ssh-askpass ];

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

    # Configure the SSH agent.
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
    };

    # Set the necessary environment variable for the SSH agent to find our script.
    home.sessionVariables = {
      SSH_ASKPASS = "${git-ssh-askpass}/bin/git-ssh-askpass";
    };
  };
}
