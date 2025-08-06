{...} @ moduleArgs:
# This file correctly passes all arguments down to the editor-logic.nix file,
# which contains the actual application definition for the text editor.
import ./editor-logic.nix moduleArgs
