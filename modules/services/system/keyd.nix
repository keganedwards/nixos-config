# In /etc/nixos/modules/nixos/services/keyd.nix
{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        # [main] section
        main = {
          # Physical 'capslock' key sends 'scrolllock' keycodes.
          # Sway's xkb_options "caps:none" ensures the OS doesn't toggle
          # CapsLock state from this key. Sway uses the 'scrolllock' event as $mod.
          capslock = "scrolllock";

          # If you have a physical 'scrolllock' key on your keyboard,
          # and you want IT to do absolutely nothing (not toggle ScrollLock state/LED),
          # map it to "void".
          # If you don't have this line and press a physical scrolllock key,
          # it will likely still toggle the scroll lock state.
          scrolllock = "void";

          # DO NOT put 'leftmeta = layer(anything)' here.
          # We will use the default 'meta' layer.
        };

        # Define bindings within keyd's default 'meta' layer.
        meta = {
          # This corresponds to [meta:M] implicitly
          # --- Arrow keys ---
          h = "left";
          j = "down";
          k = "up";
          l = "right";

          # --- Navigation ---
          e = "esc";
          d = "delete";
          y = "home";
          n = "end";
          u = "pageup";
          o = "pagedown";
          i = "insert";

          # --- F-Keys (Meta + Number Row) ---
          "0" = "f10";
          "1" = "f1";
          "2" = "f2";
          "3" = "f3";
          "4" = "f4";
          "5" = "f5";
          "6" = "f6";
          "7" = "f7";
          "8" = "f8";
          "9" = "f9";
          minus = "f11";
          equal = "f12";
        };
      };
    };
  };
}
