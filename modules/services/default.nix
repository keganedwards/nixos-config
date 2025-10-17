{username, ...}: {
  imports = [./system];
  home-manager.users.${username} = {
    imports = [./hm];
  };
}
