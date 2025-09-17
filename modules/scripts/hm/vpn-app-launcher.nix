{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellScriptBin "launch-vpn-app" ''
      #!${pkgs.bash}/bin/bash
      set -eu

      # Create the cache directory that flatpak might need
      mkdir -p "$HOME/.cache/doc/by-app"

      # Run the application through vopono
      exec ${pkgs.vopono}/bin/vopono exec --provider protonvpn --server us --protocol openvpn "$@"
    '')
  ];
}
