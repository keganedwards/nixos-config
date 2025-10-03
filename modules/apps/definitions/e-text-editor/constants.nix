{lib, ...}: {
  options.editorConstants = lib.mkOption {
    type = lib.types.attrs;
    default = {
      appIdForWM = "nvim-editor-terminal";
      packageName = "neovim";
      iconName = "nvim";
    };
  };
}
