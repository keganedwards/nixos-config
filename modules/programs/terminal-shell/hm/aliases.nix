{
  programs.fish.shellAliases = {
    # Navigation aliases
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";

    # Safety aliases
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";

    # Git aliases
    gs = "git status";
    gl = "git log --oneline --graph --decorate";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gd = "git diff";
    gco = "git checkout";
    gb = "git branch";

    # Application shortcuts
    music = "mpv --save-position-on-quit ~/Music/Instrumental";
    open = "xdg-open";
    sf = "source ~/.config/fish/config.fish";

    # Nix shortcuts
    ns = "nix-shell";
    nb = "nix build";
    ne = "nix-env";
    nf = "nix flake";
  };
}
