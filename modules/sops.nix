{
  self,
  username,
  pkgs,
  ...
}: let
  secretsSourceDir = "${self}/secrets";
  protectedUsername = "protect-${username}";
  protectedHome = "/var/lib/${protectedUsername}";
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

      # The following secrets are decrypted into the protected user's home directory
      # so they can be bind-mounted into the target user's home.
      "user-ssh-key" = {
        sopsFile = "${secretsSourceDir}/user-ssh-key.enc";
        format = "binary";
        owner = protectedUsername;
        group = "protected-users";
        mode = "0600";
        path = "${protectedHome}/.ssh/id_ed25519";
      };

      "protonvpn_auth" = {
        sopsFile = "${secretsSourceDir}/auth.txt.enc";
        format = "binary";
        owner = protectedUsername;
        group = "protected-users";
        mode = "0600";
        path = "${protectedHome}/.config/vopono/proton/openvpn/auth.txt";
      };

      "protonvpn_config" = {
        sopsFile = "${secretsSourceDir}/united_states-us-free.ovpn.enc";
        format = "binary";
        owner = protectedUsername;
        group = "protected-users";
        mode = "0640";
        path = "${protectedHome}/.config/vopono/proton/united_states-us-free.ovpn";
      };
    };
  };
}
