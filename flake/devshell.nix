{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      inherit (config.checks.pre-commit-check) shellHook;
      buildInputs = config.checks.pre-commit-check.enabledPackages;
    };
  };
}
