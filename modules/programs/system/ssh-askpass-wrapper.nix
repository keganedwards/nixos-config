# /modules/programs/system/ssh-askpass-wrapper.nix
{
  config,
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
  sshPassphraseSecretFile = config.sops.secrets."ssh-key-passphrase".path;

  # Create ssh-askpass that will be available system-wide
  ssh-askpass-wrapper = pkgs.writeShellScriptBin "ssh-askpass" ''
    #!${pkgs.stdenv.shell}
    exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cat ${sshPassphraseSecretFile}
  '';
in {
  # Install ssh-askpass in system PATH so it's in /run/current-system/sw/bin
  environment.systemPackages = [ssh-askpass-wrapper];

  # Also add it to protected user's home for extra security
  home-manager.users.${protectedUsername} = {
    home.packages = [ssh-askpass-wrapper];
  };
}
