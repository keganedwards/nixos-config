# /modules/system/sops.nix
{
  self,
  username,
  pkgs,
  ...
}: let
  secretsSourceDir = "${self}/secrets";
in {
  # This section adds the sops package to the system's PATH
  environment.systemPackages = [
    pkgs.sops
    pkgs.age
  ];

  sops = {
    age.keyFile = "/root/.config/sops/age/keys.txt";

    secrets = {
      # The "user-password" block has been removed.
      # The user password will now be managed imperatively with `passwd`.

      "ssh-key-passphrase" = {
        sopsFile = "${secretsSourceDir}/system-secrets.yaml";
        key = "data";
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "user-ssh-key" = {
        sopsFile = "${secretsSourceDir}/user-ssh-key.enc";
        format = "binary";
        owner = username;
        group = "users";
        mode = "0600";
        path = "/home/${username}/.ssh/id_ed25519";
      };

      "protonvpn_auth" = {
        sopsFile = "${secretsSourceDir}/auth.txt.enc";
        format = "binary";
        owner = username;
        group = "users";
        mode = "0600";
        path = "/home/${username}/.config/vopono/proton/openvpn/auth.txt";
      };

      "protonvpn_config" = {
        sopsFile = "${secretsSourceDir}/united_states-us-free.ovpn.enc";
        format = "binary";
        owner = username;
        group = "users";
        mode = "0640";
        path = "/home/${username}/.config/vopono/proton/united_states-us-free.ovpn";
      };
    };
  };
}
