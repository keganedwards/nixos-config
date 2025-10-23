# /modules/programs/terminal-shell/hm/init.nix
{pkgs, ...}: {
  programs.fish = {
    shellInit = ''
      # Suppress welcome message
      set -g fish_greeting ""

      # Override RIPGREP_CONFIG_PATH to point to the correct user's home
      set -gx RIPGREP_CONFIG_PATH ~/.config/ripgrep/ripgreprc
    '';

    interactiveShellInit = ''
      # Initial directory listing on startup
      if not set -q __initial_listing_done
        set -g __initial_listing_done 1
        ${pkgs.eza}/bin/eza -la
        echo
      end
    '';
  };

  xdg.configFile."fish/conf.d/.keep".text = "";
}
