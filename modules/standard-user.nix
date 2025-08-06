# /modules/users/standard-user.nix
{
  username,
  fullName,
flakeConstants,
  ...
}: {

  users.users.${username} = {
    isNormalUser = true;
    description = fullName;
    extraGroups = ["keyd" "input" "uinput" "networkmanager" "wheel" "libvirtd" "video" "keys" "tss" "nix-admins"];
  };
  home-manager.users.${username} = {
    home.stateVersion = flakeConstants.stateVersion; 
  };
}
