{
  self,
  username,
  pkgs,
  ...
}: let
  secretsSourceDir = "${self}/secrets";
  userHome = "/home/${username}";
in {
  # This section adds the sops package to the system's PATH
  environment.systemPackages = [
    pkgs.sops
    pkgs.age
  ];

  sops = {
    age.keyFile = "/root/.config/sops/age/keys.txt";

    secrets = {
      # This secret is owned by root and is not part of the protected mount system.
      "ssh-key-passphrase" = {
        sopsFile = "${secretsSourceDir}/system-secrets.yaml";
        key = "data";
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # The following secrets are decrypted into the user's home directory.
      "user-ssh-key" = {
        sopsFile = "${secretsSourceDir}/user-ssh-key.enc";
        format = "binary";
        owner = "${username}";
        group = "users";
        mode = "0600";
        path = "${userHome}/.ssh/id_ed25519";
      };
    };
  };
}
