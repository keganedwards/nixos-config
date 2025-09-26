{
  type = "flatpak";
  id = "org.nicotine_plus.Nicotine";
  key = "bracketleft";
  launchCommand = "sh -c 'sleep 1 && exec launch-vpn-app flatpak run org.nicotine_plus.Nicotine'";
  autostartPriority = 10;
}
