{
  pkgs,
  username,
  flakeDir,
  terminalConstants,
  terminalShellConstants,
  ...
}: let
  nixos-test-build = pkgs.writeShellScriptBin "nixos-test-build" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    TARGET_COMMIT="$1"

    cd "${flakeDir}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NixOS Test Build"
    echo "  Commit: ''${TARGET_COMMIT:0:7}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "The build will show a comparison and ask for"
    echo "confirmation. Type 'y' or 'yes' to proceed."
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    /run/current-system/sw/bin/secure-rebuild "$TARGET_COMMIT" test --ask
    BUILD_RESULT=$?

    if [ $BUILD_RESULT -eq 0 ]; then
      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Post-build actions..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      if command -v ${terminalShellConstants.name} >/dev/null 2>&1; then
        echo -n "  Reloading ${terminalShellConstants.name} configuration... "
        runuser -u ${username} -- ${terminalShellConstants.reloadCommand} >/dev/null 2>&1 || true
        echo "done"
      fi

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo
    fi

    exit $BUILD_RESULT
  '';

  nixos-test-wrapper = pkgs.writeShellScriptBin "nt" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd "${flakeDir}"

    force_rebuild=0

    while [[ $# -gt 0 ]]; do
      case $1 in
        -f|--force)
          force_rebuild=1
          shift
          ;;
        -h|--help)
          echo "Usage: nixos-test [-f|--force]"
          echo "  -f, --force      Force rebuild even if repository is clean"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    if [ "$force_rebuild" -eq 1 ]; then
      TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      echo "✅ Force flag detected. Proceeding with rebuild."
      echo ":: Building from commit: ''${TARGET_COMMIT:0:7}"
      echo ":: Authenticating for NixOS test build..."

      if exec sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"; then
        ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!"
        exit 0
      else
        ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!"
        exit 1
      fi
    fi

    if ! ${pkgs.git}/bin/git diff --quiet HEAD || [ -n "$(${pkgs.git}/bin/git ls-files --others --exclude-standard)" ]; then
      echo ":: Uncommitted changes detected."

      original_head=$(${pkgs.git}/bin/git rev-parse HEAD)

      ${pkgs.git}/bin/git add .

      if ! ${pkgs.git}/bin/git diff --quiet --staged; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Commit message (empty to amend):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        IFS= read -r commit_msg

        if [ -z "$commit_msg" ]; then
          ${pkgs.git}/bin/git commit --amend --no-edit --quiet
          echo ":: Amended last commit"
        else
          ${pkgs.git}/bin/git commit -m "$commit_msg" --quiet
          echo ":: Created new commit"
        fi

        TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      else
        echo ":: No changes to commit (all changes were already staged)"
        TARGET_COMMIT="$original_head"
      fi

      if [ "$TARGET_COMMIT" != "$original_head" ]; then
        if command -v ${terminalConstants.name} >/dev/null && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          setsid -f ${terminalConstants.bin} start --class nixos-diff \
            ${pkgs.bash}/bin/bash -c "
              cd '${flakeDir}'
              echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
              echo '  Git Diff Review'
              echo '  Commit: ''${TARGET_COMMIT:0:7}'
              echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
              echo
              echo 'Review your changes (press q to exit diff):'
              ${pkgs.git}/bin/git diff --color=always '$original_head' '$TARGET_COMMIT' | ${pkgs.less}/bin/less -R
            " &

          echo ":: Diff review terminal launched."
        else
          echo ":: No graphical terminal available — showing diff here before build."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Git Diff Review"
          echo "  Commit: ''${TARGET_COMMIT:0:7}"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo
          echo "Review your changes (press q to exit diff):"
          ${pkgs.git}/bin/git diff --color=always "$original_head" "$TARGET_COMMIT" | ${pkgs.less}/bin/less -R
        fi
      fi

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ":: Starting NixOS test build for commit: ''${TARGET_COMMIT:0:7}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo

      exec sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"

    else
      echo "✅ Repository is clean. No changes to test."
      echo "    Use -f or --force to rebuild anyway."
      exit 0
    fi
  '';

  nt-wrapper = pkgs.writeShellScriptBin "nt" ''
    #!${pkgs.bash}/bin/bash
    ${nixos-test-wrapper}/bin/nt "$@"
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
      ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!" 2>/dev/null || true
    else
      ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!" 2>/dev/null || true
    fi
    exit $RESULT
  '';
in {
  environment.systemPackages = with pkgs; [
    nixos-test-build
    nt-wrapper
  ];

  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${nixos-test-build}/bin/nixos-test-build";
          options = ["NOPASSWD"];
        }
        {
          command = "${nixos-test-build}/bin/nixos-test-build *";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
