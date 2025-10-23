{pkgs, ...}: {
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        meta = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";

          e = "esc";
          d = "delete";
          y = "home";
          n = "end";
          u = "pageup";
          o = "pagedown";
          i = "insert";

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
