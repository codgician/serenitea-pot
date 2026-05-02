{ lib, ... }:

# Upstream fix: https://github.com/NixOS/nixpkgs/pull/515474
# todo: remove when fix is merged.
let
  primpFix =
    pyfinal: pyprev:
    lib.optionalAttrs (pyprev ? primp) {
      primp = pyprev.primp.overridePythonAttrs (old: {
        pytestFlags = (old.pytestFlags or [ ]) ++ (old.pytestFlagsArray or [ ]);
        # Empty list is allowed; nixpkgs only errors when the deprecated
        # attribute is set to a non-empty value.
        pytestFlagsArray = [ ];
      });
    };
in
final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [ primpFix ];

  # `prev.unstable` is a separately-imported package set, so our overlay does
  # not reach it. Re-extend it via overlay so unstable's primp is also patched.
  unstable = prev.unstable.extend (
    unstableFinal: unstablePrev: {
      pythonPackagesExtensions = (unstablePrev.pythonPackagesExtensions or [ ]) ++ [
        primpFix
      ];
    }
  );
}
