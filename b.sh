#!/bin/bash

# Exit immediately if any command fails.
set -e

# --- SCRIPT START ---

# 1. Capture the commit message from the current HEAD.
#    We will reuse this for the new squashed commit.
echo "Capturing commit message from the latest commit..."
COMMIT_MESSAGE=$(git log -1 --pretty=%B HEAD)

# 2. Reset the branch pointer two commits back.
#    The --soft flag is crucial: it erases the commits from history
#    but leaves all the file changes from those commits in the staging area.
#    Your working directory is untouched.
echo "Resetting history back two commits..."
git reset --soft HEAD~2

# 3. Create a new, single, SIGNED commit.
#    -S tells Git to sign the commit using your configured key.
#    -m provides the commit message directly, avoiding an interactive editor.
echo "Creating new, signed commit..."
git commit -S -m "$COMMIT_MESSAGE"

echo ""
echo "✅ Success! Local history has been rewritten."
echo "The last two commits have been squashed into a new, signed commit."
echo ""
echo "--> Verify with 'git log'."
echo "--> When you are ready, you MUST force-push to update the remote:"
echo "    git push --force-with-lease origin main"
