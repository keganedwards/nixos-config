{config, ...}: let
  # Path to the SOPS‐managed private key symlink you set up
  sshKey = "${config.home.homeDirectory}/.ssh/id_ed25519";
in {
  programs.ssh.enable = true;
  programs.ssh.addKeysToAgent = "yes";

  # Define per‑host SSH settings
  programs.ssh.matchBlocks = {
    "github.com" = {
      user = "git";
      identityFile = sshKey;
      identitiesOnly = true;
    };
  };
}
