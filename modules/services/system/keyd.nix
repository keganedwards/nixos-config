{pkgs, ...}: {
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        # [main] section - REMAINS UNCHANGED
        main = {
          capslock = "scrolllock";
          scrolllock = "void";
        };

        # Define bindings within keyd's default 'meta' layer.
        meta = {
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
  environment.systemPackages = [pkgs.keyd];
}
