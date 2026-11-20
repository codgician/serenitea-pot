# Use electron 43+ for hardware accelerated decoding
# todo: remove when nixpkgs electron default version is updated to 43+

{ lib, fromUnstable, ... }:

lib.composeManyExtensions [
  (final: prev: {
    bilibili = prev.bilibili.override { electron = final.electron_43; };
  })

  (fromUnstable [ "bilibili" ])
]
