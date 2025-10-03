{
  username,
  fullName,
  stateVersion,
  ...
}: {
  users.users.${username} = {
    isNormalUser = true;
    description = fullName;
    extraGroups = ["keyd" "networkmanager" "wheel" "libvirtd" "video" "keys" "tss"];
  };
  home-manager = {
    backupFileExtension = "backup";
    users.${username}.home.stateVersion = stateVersion;
  };
}
