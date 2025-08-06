# /modules/home-manager/scripts/config-git-push-script.nix
{
  config, # Home Manager configuration object
  pkgs,
  lib,
  # --- REMOVED: sopsDecryptionKeyFile is no longer a special argument ---
  ...
}: let
  # --- CHANGED: Get the key file path from the config object ---
  # This is the correct, non-recursive way to access this value.
  sopsKeyFile = config.sops.age.keyFile;

  userHome = config.home.homeDirectory;
  dotfilesDir = "${userHome}/.dotfiles";
  gitRemote = "origin";
  gitBranch = "main";

  # Files to encrypt with SOPS
  sopsManagedFiles = [
    {
      liveFile = "${userHome}/.var/app/org.nicotine_plus.Nicotine/config/nicotine/config";
      repoEncryptedFile = "${dotfilesDir}/secrets/nicotine_config.enc";
    }
    # …add more entries here…
  ];

  # Build the Phase 1 encryption loop as a standalone Nix string
  phase1Loop =
    lib.concatMapStringsSep "\n" (file: ''
      LIVE_FILE="${file.liveFile}"
      REPO_ENC_FILE="${file.repoEncryptedFile}"
      log_info "Processing: $LIVE_FILE → $REPO_ENC_FILE"

      if [ ! -e "$LIVE_FILE" ]; then
        log_warn "Live file missing: '$LIVE_FILE'; skipping."
      else
        NEEDS_ENCRYPTION=false

        if [ -f "$REPO_ENC_FILE" ]; then
          # --- CHANGED: Use the sopsKeyFile variable ---
          if DECRYPTED=$(env SOPS_AGE_KEY_FILE="${sopsKeyFile}" sops --decrypt "$REPO_ENC_FILE" 2>/dev/null) && \
             cmp -s "$LIVE_FILE" <(echo "$DECRYPTED"); then
            log_info "'$REPO_ENC_FILE' up-to-date."
          else
            log_info "Change detected for '$LIVE_FILE'."
            NEEDS_ENCRYPTION=true
          fi
        else
          log_info "No encrypted file at '$REPO_ENC_FILE'; will create."
          NEEDS_ENCRYPTION=true
        fi

        if [ "$NEEDS_ENCRYPTION" = true ]; then
          log_info "Encrypting '$LIVE_FILE' → '$REPO_ENC_FILE'…"
          mkdir -p "$(dirname "$REPO_ENC_FILE")"
          TMP=$(mktemp)
          # --- CHANGED: Use the sopsKeyFile variable ---
          if env SOPS_AGE_KEY_FILE="${sopsKeyFile}" \
              sops --encrypt --age "$USER_AGE_PUBKEY" \
                        --input-type binary --output "$TMP" "$LIVE_FILE"; then
            mv "$TMP" "$REPO_ENC_FILE"
            log_info "Updated '$REPO_ENC_FILE'."
          else
            log_err "Encryption failed for '$REPO_ENC_FILE'."
            SOPS_UPDATE_FAILED=true
          fi
          rm -f "$TMP"
        fi
      fi
    '')
    sopsManagedFiles;

  # The full script
  script = ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Variables
    DOTFILES_DIR="${dotfilesDir}"
    # --- CHANGED: Use the sopsKeyFile variable defined in the Nix `let` block ---
    SOPS_KEY_FILE="${sopsKeyFile}"
    GIT_REMOTE="${gitRemote}"
    GIT_BRANCH="${gitBranch}"
    LOG_TAG="cgp[$USER]"

    # ... (rest of the script is unchanged) ...
    log_info() { echo "[INFO] $1" >&2; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_err()  { echo "[ERROR] $1" >&2; }
    if [ $# -ne 1 ]; then log_err "Usage: cgp \"<commit-message>\""; exit 1; fi
    COMMIT_MSG="$1"
    log_info "Checking prerequisites…"
    if ! [ -d "$DOTFILES_DIR" ]; then log_err "Missing $DOTFILES_DIR"; exit 1; fi
    if ! git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree &>/dev/null; then log_err "$DOTFILES_DIR is not a git repo"; exit 1; fi
    if ! command -v sops &>/dev/null; then log_err "sops not installed"; exit 1; fi
    if ! [ -r "$SOPS_KEY_FILE" ]; then log_err "Cannot read SOPS key $SOPS_KEY_FILE"; exit 1; fi
    log_info "Extracting Age public key…"
    if ! USER_AGE_PUBKEY=$(age-keygen -y "$SOPS_KEY_FILE"); then log_err "age-keygen failed"; exit 1; fi
    if ! [[ "$USER_AGE_PUBKEY" =~ ^age1[0-9a-z]{58}$ ]]; then log_err "Bad Age key format: $USER_AGE_PUBKEY"; exit 1; fi
    log_info "=== Phase 1: Updating SOPS files ==="
    SOPS_UPDATE_FAILED=false
    ${phase1Loop}
    if [ "$SOPS_UPDATE_FAILED" = true ]; then log_err "One or more SOPS ops failed. Aborting."; exit 1; fi
    log_info "Phase 1 complete."
    log_info "=== Phase 2: Git operations ==="
    git -C "$DOTFILES_DIR" add .
    if git -C "$DOTFILES_DIR" diff --cached --quiet; then log_info "No changes to commit."; exit 0; fi
    git -C "$DOTFILES_DIR" commit -m "$COMMIT_MSG"
    git -C "$DOTFILES_DIR" push "$GIT_REMOTE" "$GIT_BRANCH"
    log_info "Config push successful!"
  '';
in {
  home.packages = with pkgs; [
    git
    sops
    age
    (writeShellScriptBin "cgp" script)
  ];
}
