{
  programs.fish.functions = {
    mkcd = ''
      if test (count $argv) -eq 0
        echo "Usage: mkcd <directory>"
        return 1
      end

      mkdir -p $argv[1]
      and cd $argv[1]
    '';

    op = ''
      if count $argv > /dev/null
        command xdg-open $argv >/dev/null 2>&1 &
      else
        echo "Usage: op <file_or_url>..." >&2
        return 1
      end
    '';
  };
}
