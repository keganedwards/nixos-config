{username, lib, ...}: {
  services = {
    # System and background services
    qemuGuest.enable = true;
    spice-vdagentd.enable = true;
    ollama.enable = true;
    avahi.enable = true;
    geoclue2.enable = true;
    printing.enable = true;
    udisks2.enable = true;
gnome.gnome-keyring.enable = lib.mkForce false;
        };

home-manager.users.${username}.services.gnome-keyring = {
                enable = true;
                components = lib.mkForce ["pkcs11" "secrets"];
        };

}
