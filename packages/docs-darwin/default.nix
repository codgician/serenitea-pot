{
  lib,
  stdenv,
  options ?
    (lib.codgician.mkDarwinSystem {
      hostName = "darwin";
      inherit (stdenv.hostPlatform) system;
    }).options,
  docs-nixos,
  ...
}:

docs-nixos.override { inherit options; }
// {
  meta = with lib; {
    description = "Documentation for serenitea-pot on Darwin (macOS)";
    maintainers = with maintainers; [ codgician ];
    platforms = platforms.linux ++ [ "aarch64-darwin" ];
  };
}
