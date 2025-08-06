# Custom NixOS Management Scripts: `ns` and `ngp`

This repository uses two custom scripts, `ns` and `ngp`, to manage the NixOS/Home Manager configuration lifecycle, integrating Git for version control and SOPS for secrets management.

## `ns` (Nix Switch/Build)

**Purpose:** To build and test the *local* NixOS/Home Manager configuration changes. It handles staging changes and creates validated, automatic commits on a dedicated branch (`auto-commits`) after successful builds.

**Key Actions:**

1.  **Stages All Changes:** Runs `git add .` within the repository root to stage all current working directory changes.
2.  **Branch Handling:**
    *   If currently on `main`: Switches to `auto-commits` (creating it if needed) and merges the staged changes from `main` into `auto-commits`.
    *   If currently on `auto-commits`: Proceeds directly.
    *   If on any other branch: Warns that it will build but *not* commit changes.
3.  **Builds Configuration:** Runs `sudo nixos-rebuild test --flake .#<hostname>` using the staged configuration.
4.  **Conditional Auto-Commit:** If the build succeeds **and** the effective branch is `auto-commits`, it commits the staged changes to the `auto-commits` branch with an automatic timestamped message.
5.  **Reloads Environment:** Executes the `reload-sway-env` command (assumed to be available).
6.  **Final Branch:** Leaves the repository on the branch where the build occurred (usually `auto-commits` if changes were committed, or whichever branch was active if no commit happened).

**Usage:**

*   `ns`: Run a build, potentially creating an auto-commit on `auto-commits`.
*   `ns --force`: Force a build even if the repository appears clean.

---

## `ngp` (Nix Git Push)

**Purpose:** To synchronize specific live configuration states back into SOPS, finalize changes by integrating the `auto-commits` branch into `main`, pushing `main` to the remote, and optionally updating the system bootloader to reflect the *currently running* configuration generation.

**Key Actions:**

1.  **Sync Live Config to SOPS (If Changed):**
    *   Checks specified live configuration files (e.g., Nicotine+ Flatpak config) against their corresponding SOPS-encrypted versions (`.enc`) stored within the repository (e.g., `nixos/secrets/nicotine_config.enc`).
    *   It **decrypts** the existing `.enc` file and **compares** its content to the live file.
    *   **Only if the plaintext contents differ**, it copies the live file content over the `.enc` file path and re-encrypts it in place using `sops`. This avoids unnecessary file changes in Git if the live state hasn't actually diverged from the committed encrypted state.
    *   **Prerequisite:** This step requires the `SOPS_AGE_KEY_FILE` environment variable to be correctly set, pointing to your private age key, as decryption is needed for comparison.
2.  **Git Workflow:**
    *   Ensures it's on the `auto-commits` branch and commits any *other* staged changes (potentially including the `.enc` file if it *was* updated in step 1).
    *   Switches to the `main` branch.
    *   Fetches the remote (`origin`).
    *   Squash merges all changes from `auto-commits` into `main`.
    *   Commits the squashed changes to `main` using the **commit message provided as an argument**.
3.  **Push & Verify:** Pushes `main` to `origin` and verifies that the remote `main` hash matches the local `main` hash after fetching again. Fails if verification doesn't pass (e.g., due to branch protection).
4.  **Conditional Bootloader Update:** *Only if* the push was verified (or no push was needed), it checks if the currently running system generation (`/run/current-system`) matches the latest system profile (`/nix/var/nix/profiles/system`). If they differ, it updates the profile and runs `switch-to-configuration boot` to make the running system persistent.
5.  **Final Branch:** Leaves the repository on the `main` branch.

**Usage:**

*   `ngp "Your meaningful commit message for main"` (Ensure `SOPS_AGE_KEY_FILE` is set in your environment beforehand).

---

**Workflow Rationale:**

*   `ns` allows for frequent local builds and tests, saving successful states automatically to `auto-commits` without polluting the `main` branch history.
*   `ngp` provides a controlled way to integrate these validated changes, sync necessary live state *without creating unnecessary diffs*, create a clean commit on `main`, push, and ensure the bootloader reflects a state actually present on the remote. This separates local iteration from the finalized, pushed state.

**Dependencies/Assumptions:**

*   NixOS, Home Manager, Git, SOPS (`age` key via `SOPS_AGE_KEY_FILE`).
*   Specific branch names: `main`, `auto-commits`.
*   `reload-sway-env` command available for `ns`.
*   Specific live config paths (e.g., Nicotine+ Flatpak) and corresponding target `.enc` paths configured within the `ngp` script for the SOPS sync step.
*   Sudo permissions for `nixos-rebuild` and bootloader updates.
