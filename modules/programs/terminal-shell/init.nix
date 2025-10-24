{
  pkgs,
  username,
  ...
}: {
  home-manager.users."protect-${username}" = {
    programs.fish = {
      shellInit = ''
        set -g fish_greeting ""
        set -gx RIPGREP_CONFIG_PATH ~/.config/ripgrep/ripgreprc
      '';

      interactiveShellInit = ''
        if not set -q __initial_listing_done
          set -g __initial_listing_done 1
          ${pkgs.eza}/bin/eza -la
          echo
        end
      '';
    };

    xdg.configFile."fish/conf.d/.keep".text = "";
  };
}
