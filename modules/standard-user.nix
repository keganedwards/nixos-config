{
  username,
  fullName,
  flakeConstants,
  ...
}: {
  users.users.${username} = {
    isNormalUser = true;
    description = fullName;
    extraGroups = ["keyd" "networkmanager" "wheel" "libvirtd" "video" "keys" "tss"];
  };
  home-manager.users.${username}.home.stateVersion = flakeConstants.stateVersion;
}
