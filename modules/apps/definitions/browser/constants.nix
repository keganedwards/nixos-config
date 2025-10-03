{lib, ...}: {
  options.browserConstants = lib.mkOption {
    type = lib.types.attrs;
    default = {
      defaultFlatpakId = "com.brave.Browser";
      defaultWmClass = "Brave-browser";
      pwaRunnerFlatpakId = "com.brave.Browser";
      pwaRunnerWmClass = "Brave-browser";
    };
  };
}
