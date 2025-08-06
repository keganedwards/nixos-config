{
  type = "flatpak";
  id = "org.nicotine_plus.Nicotine";
  key = "bracketleft";
  autostartPriority = 13;
  launchCommand = "exec run-vpn-app org.nicotine_plus.Nicotine";
  vpn = {
    enabled = true;
  };
}
