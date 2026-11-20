# Use version from unstable for specified kernel modules

{ lib, fromUnstable, ... }:

lib.composeManyExtensions [
  (fromUnstable [ "mstflint" ])
  (fromUnstable.kernel [ "mstflint_access" ])
]
