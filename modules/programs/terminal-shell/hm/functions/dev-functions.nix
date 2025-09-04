{
  programs.fish.functions = {
    haskellEnv = ''
      if test (count $argv) -lt 1
        echo "Usage: haskellEnv <package1> [package2 ...]" >&2
        echo "Example: haskellEnv lens containers" >&2
        return 1
      end

      set -l haskell_pkgs (string join ' ' $argv)
      echo "Starting nix-shell with GHC and packages: $haskell_pkgs"
      nix-shell -p "haskellPackages.ghcWithPackages (pkgs: with pkgs; [ $haskell_pkgs ])" --run fish
    '';

    pythonEnv = ''
      if test (count $argv) -lt 1
        echo "Usage: pythonEnv <py_version> [package1 package2 ...]" >&2
        echo "Example: pythonEnv 311 requests numpy" >&2
        return 1
      end

      set -l pythonVersion $argv[1]
      set -l ppkgs_list

      if not string match -qr '^[0-9]+$' -- $pythonVersion
        echo "Error: Python version '$pythonVersion' should be numbers only (e.g., 311 for 3.11)" >&2
        return 1
      end

      for pkg_name in $argv[2..-1]
        set -a ppkgs_list "python$pythonVersion"Packages."$pkg_name"
      end

      set -a ppkgs_list "python$pythonVersion"
      echo "Starting nix-shell with:" (string join ' ' $ppkgs_list)
      nix-shell -p $ppkgs_list --run fish
    '';
  };
}
