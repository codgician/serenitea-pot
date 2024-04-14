{ lib, ... }: 
let
  dirContent = builtins.readDir ./.;
  dirNames = builtins.filter (name: dirContent.${name} == "directory") (builtins.attrNames dirContent);
in
{
  imports = builtins.map (x: ./. + "/${x}") dirNames;
}