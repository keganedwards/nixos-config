{
  # 1) Tell HM not to install it—just wrap the existing “nmtui” binary.
  id = "nmtui";

  # 2) Sway keybinding hint (you want to press “period” to open it)
  key = "period";

  # 3) Mark it as a terminal application so mkApp wraps it in your terminal (foot, etc.)
  isTerminalApp = true;
}
