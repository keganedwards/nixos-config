{username, ...}: {
  home-manager.users."protect-${username}".programs.fish.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";
    gs = "git status";
    gl = "git log --oneline --graph --decorate";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gd = "git diff";
    gco = "git checkout";
    gb = "git branch";
    music = "mpv --save-position-on-quit ~/Music/Instrumental";
    open = "xdg-open";
    sf = "source ~/.config/fish/config.fish";
    ns = "nix-shell";
    nb = "nix build";
    ne = "nix-env";
    nf = "nix flake";
  };
}
