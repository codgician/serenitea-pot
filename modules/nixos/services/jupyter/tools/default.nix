# Internal tools for Jupyter service
# These are implementation details, not exposed as flake-level applications
{
  pkgs,
  lib,
  ...
}:

{
  venv-kernel-manager = pkgs.callPackage ./venv-kernel-manager { inherit lib; };

  # Future tools can be added here:
  # notebook-exporter = pkgs.callPackage ./notebook-exporter { inherit lib; };
  # kernel-debugger = pkgs.callPackage ./kernel-debugger { inherit lib; };
}
