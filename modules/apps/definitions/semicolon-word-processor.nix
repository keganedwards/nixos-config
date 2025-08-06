{
  type = "flatpak";
  id = "com.abisource.AbiWord";
  key = "semicolon";
  flatpakOverride = {
    Context.filesystems = ["home" "xdg-documents"];
  };
}
