{username, ...}: {
  config.rawAppDefinitions.image-viewer = {
    type = "nix";
    id = "swayimg";
    key = "i";
  };
  config.home-manager.users.${username}.programs.swayimg.enable = true;
}
