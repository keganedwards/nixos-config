{
  services.pipewire = {
    enable = true;
    alsa.support32Bit = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };
}
