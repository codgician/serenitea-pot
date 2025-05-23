{ ... }:
{
  convertImage =
    pkgs: path:
    {
      args,
      outName ? "image",
    }:
    (pkgs.stdenvNoCC.mkDerivation {
      name = "converted-${outName}";
      src = path;
      buildInputs = [ pkgs.imagemagick ];
      buildCommand = ''
        mkdir -p $out
        convert ${path} ${args} $out/${outName}
      '';
    }).outPath
    + "/${outName}";
}
