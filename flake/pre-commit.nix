{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = {
      pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
        src = ../.;
        hooks = {
          trufflehog.enable = true;
          detect-private-keys.enable = true;
          check-added-large-files.enable = true;
          check-case-conflicts.enable = true;
          check-merge-conflicts.enable = true;
          check-symlinks.enable = true;
          forbid-new-submodules.enable = true;
          alejandra.enable = true;
          typos = {
            enable = true;
            settings = {
              ignored-words = [
                "als" # False positive for abbreviation/name
                "enew" # Nvim command for new empty buffer
              ];
            };
          };
          statix = {
            enable = true;
            settings.ignore = [
              "**/hardware-configuration.nix"
            ];
          };
          deadnix = {
            enable = true;
            settings.edit = true;
          };
          flake-checker.enable = true;
          validate-flatpaks = {
            enable = true;
            name = "validate-flatpaks";
            description = "Validate Flatpak IDs against Flathub";
            entry = let
              validateScript = pkgs.writeShellScript "validate-flatpaks" ''
                                #!${pkgs.bash}/bin/bash
                                set -euo pipefail

                                # Define the definitions directory
                                definitionsDir="modules/apps/definitions"

                                # Get all staged files
                                staged_files=$(${pkgs.git}/bin/git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

                                # Filter for .nix files in the definitions directory
                                nix_files=""
                                for file in $staged_files; do
                                  if [[ "$file" == "$definitionsDir"/*.nix ]]; then
                                    if [ -n "$nix_files" ]; then
                                      nix_files="$nix_files"$'\n'"$file"
                                    else
                                      nix_files="$file"
                                    fi
                                  fi
                                done

                                # Exit if no relevant files
                                if [ -z "$nix_files" ]; then
                                  exit 0
                                fi

                                echo ":: Validating potential Flatpak IDs in staged definition files..."

                                failed=0
                                checked_count=0
                                error_messages=""

                                while IFS= read -r file; do
                                  [ -z "$file" ] && continue
                                  [ -f "$file" ] || continue

                                has_flatpak_type=$(grep -E 'type\s*=\s*"flatpak"' "$file" 2>/dev/null || true)
                has_other_type=$(grep -E 'type\s*=\s*"(pwa|web-page|nix|blank|externally-managed|custom)"' "$file" 2>/dev/null || true)
                # Use grep -oP for perl-compatible regex to get the capture group
                ids=$(grep -oP 'id\s*=\s*"([^"]+)"' "$file" 2>/dev/null | sed 's/id\s*=\s*"\([^"]*\)"/\1/' || true)
                                  while IFS= read -r id; do
                                    [ -z "$id" ] && continue

                                    # Count the number of dots
                                    dot_count=$(echo "$id" | tr -cd '.' | wc -c)

                                    # Only check if:
                                    # 1. It has at least 2 dots (reverse domain notation)
                                    # 2. Either explicitly marked as flatpak OR not explicitly marked as something else
                                    if [ "$dot_count" -ge 2 ]; then
                                      # Skip if explicitly marked as non-flatpak type
                                      if [ -n "$has_other_type" ] && [ -z "$has_flatpak_type" ]; then
                                        continue
                                      fi

                                      # Skip if it looks like a URL (contains :// or starts with http)
                                      if [[ "$id" == *"://"* ]] || [[ "$id" == "http"* ]]; then
                                        continue
                                      fi

                                      checked_count=$((checked_count + 1))
                                      echo -n "  Checking $id (from $(basename "$file"))... "

                                      # Try to fetch from Flathub API
                                      http_code=$(${pkgs.curl}/bin/curl -o /tmp/flatpak_response.json -w "%{http_code}" -sfL "https://flathub.org/api/v1/apps/$id" 2>/dev/null || echo "000")

                                      if [ "$http_code" != "200" ]; then
                                        echo "❌ Not found on Flathub"
                                        error_messages="$error_messages"$'\n'"  ❌ $id is not a valid Flatpak ID on Flathub"
                                        failed=1
                                        continue
                                      fi

                                      # Extract the canonical ID from the response
                                      canon=$(${pkgs.jq}/bin/jq -r '.flatpakAppId // empty' < /tmp/flatpak_response.json 2>/dev/null)

                                      if [ -z "$canon" ]; then
                                        echo "❌ Invalid response from Flathub"
                                        error_messages="$error_messages"$'\n'"  ❌ Got invalid response for $id"
                                        failed=1
                                        continue
                                      fi

                                      if [ "$id" != "$canon" ]; then
                                        echo "❌ Mismatch"
                                        error_messages="$error_messages"$'\n'"  ❌ '$id' should be '$canon'"
                                        failed=1
                                      else
                                        echo "✅"
                                      fi
                                    fi
                                  done <<< "$ids"
                                done <<< "$nix_files"

                                # Clean up temp file
                                rm -f /tmp/flatpak_response.json

                                if [ $failed -eq 1 ]; then
                                  echo
                                  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                                  echo "❌ Flatpak validation failed!"
                                  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                                  echo "$error_messages"
                                  echo
                                  echo "Please fix the IDs above before committing."
                                  exit 1
                                fi

                                if [ $checked_count -gt 0 ]; then
                                  echo
                                  echo "✅ All $checked_count Flatpak IDs validated successfully"
                                fi

                                exit 0
              '';
            in "${validateScript}";
            files = "^modules/apps/definitions/.*\\.nix$";
            pass_filenames = false;
            stages = ["pre-commit"]; # Changed from "commit" to "pre-commit"
          };
        };
      };
    };
  };
}
