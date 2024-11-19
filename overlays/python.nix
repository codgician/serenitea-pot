# Override python packages

{ inputs, lib, ... }:

self: super:
let
  isAttr = x: lib.hasPrefix "python" x && lib.hasSuffix "Packages" x;
  attrs = builtins.filter isAttr (builtins.attrNames super);
in
builtins.listToAttrs (builtins.map
  (name: {
    inherit name;
    value = super.${name}.overrideScope (ppself: ppsuper: {
      torch = ppsuper.torch-bin;  # Always use prebuilt pytorch
    });
  })
  attrs)
