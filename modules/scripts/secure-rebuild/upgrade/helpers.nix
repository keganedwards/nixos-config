{
  pkgs,
  config,
  username,
  fullName,
  email,
  ...
}: let
  sshPassphraseFile = config.sops.secrets."ssh-key-passphrase".path;

  # Shared git+ssh operation helper - simpler approach
  gitSshHelper = pkgs.writeShellScript "git-ssh-helper" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Usage: git-ssh-helper <operation> <directory> [additional-args...]
    # Operations: fetch, pull, push, commit

    OPERATION=$1
    WORK_DIR=$2
    shift 2

    # Read passphrase as root (this script runs as root)
    PASSPHRASE=$(cat ${sshPassphraseFile})
    if [ -z "$PASSPHRASE" ]; then
      echo "ERROR: Failed to read SSH passphrase" >&2
      exit 1
    fi

    cd "$WORK_DIR" || exit 1

    # Configure git for this operation
    export GIT_AUTHOR_NAME='${fullName}'
    export GIT_AUTHOR_EMAIL='${email}'
    export GIT_COMMITTER_NAME='${fullName}'
    export GIT_COMMITTER_EMAIL='${email}'

    case "$OPERATION" in
      fetch|pull|push)
        # For remote operations, use root's known_hosts
        export HOME="/root"
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/root/.ssh/known_hosts"

        ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          ${pkgs.git}/bin/git \
            -c safe.directory="$WORK_DIR" \
            -c user.name="${fullName}" \
            -c user.email="${email}" \
            "$OPERATION" "$@"
        ;;
      commit)
        # For commit with signing, use user's SSH files
        export HOME="/home/${username}"
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=yes"

        ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          ${pkgs.git}/bin/git \
            -c safe.directory="$WORK_DIR" \
            -c user.name="${fullName}" \
            -c user.email="${email}" \
            -c user.signingkey="/home/${username}/.ssh/id_ed25519.pub" \
            -c gpg.format=ssh \
            -c gpg.ssh.allowedSignersFile="/home/${username}/.ssh/allowed_signers" \
            -c gpg.ssh.program="${pkgs.openssh}/bin/ssh-keygen" \
            -c commit.gpgsign=true \
            commit "$@"
        ;;
      *)
        echo "ERROR: Unknown operation: $OPERATION" >&2
        exit 1
        ;;
    esac
  '';

  # Logging helpers
  loggingHelpers = ''
    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }
    log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }
  '';
in {
  inherit gitSshHelper loggingHelpers;
}
