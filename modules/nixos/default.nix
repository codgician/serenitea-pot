let
  dirs = builtins.readDir ./.;
  dirNames = builtins.filter (name: dirs.${name} == "directory") (builtins.attrNames dirs);
in
{
  # Import modules under every directory
  imports = builtins.map (x: import ./${x}) (dirNames ++ [ "../overlays" "../users" ]);
}
