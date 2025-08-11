# test-ssh-signing.nix
{
  pkgs,
  config,
  username,
  flakeDir,
  ...
}: let
  # Get the SSH askpass from the user's home-manager config
  sshAskpass = config.home-manager.users.${username}.home.sessionVariables.SSH_ASKPASS;

  testSSHSigning = pkgs.writeShellScript "test-ssh-signing" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "=== Testing SSH Git Signing ==="

    # Create a test directory
    TEST_DIR="/tmp/ssh-signing-test-$$"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # Initialize git repo as the user
    runuser -u ${username} -- ${pkgs.git}/bin/git init
    runuser -u ${username} -- ${pkgs.git}/bin/git config user.name "Test User"
    runuser -u ${username} -- ${pkgs.git}/bin/git config user.email "test@example.com"
    runuser -u ${username} -- ${pkgs.git}/bin/git config gpg.format ssh
    runuser -u ${username} -- ${pkgs.git}/bin/git config user.signingkey ~/.ssh/id_ed25519.pub

    # Create a test file
    echo "Test content $(date)" > test.txt
    chown ${username}:users test.txt
    runuser -u ${username} -- ${pkgs.git}/bin/git add test.txt

    # Set up SSH askpass environment
    export SSH_ASKPASS="${sshAskpass}"
    export SSH_ASKPASS_REQUIRE="force"
    export DISPLAY=:0  # Required for SSH_ASKPASS to work

    # Try to commit with signing
    echo "Attempting to create signed commit..."
    if runuser -u ${username} --preserve-environment=SSH_ASKPASS,SSH_ASKPASS_REQUIRE,DISPLAY -- \
        ${pkgs.git}/bin/git commit -S -m "Test commit"; then
      echo "✅ Commit created successfully!"

      # Verify the commit
      echo "Verifying commit signature..."
      if runuser -u ${username} -- ${pkgs.git}/bin/git verify-commit HEAD; then
        echo "✅ Signature verified!"
      else
        echo "❌ Signature verification failed"
        exit 1
      fi
    else
      echo "❌ Failed to create signed commit"
      exit 1
    fi

    # Cleanup
    cd /
    rm -rf "$TEST_DIR"

    echo "=== Test completed successfully! ==="
  '';
in {
  systemd.services."test-ssh-signing" = {
    description = "Test SSH Git Signing";
    serviceConfig = {
      Type = "oneshot";
      User = "root"; # Run as root
      Environment = [
        "HOME=/home/${username}"
        "PATH=${pkgs.git}/bin:${pkgs.gnupg}/bin:${pkgs.openssh}/bin:/run/current-system/sw/bin"
      ];
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      ExecStart = testSSHSigning;
    };
  };

  security.sudo.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl start test-ssh-signing.service";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "test-ssh-signing";
      runtimeInputs = [pkgs.systemd];
      text = "sudo systemctl start test-ssh-signing.service";
    })
  ];
}
