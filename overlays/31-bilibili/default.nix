# Use electron 43+ for hardware accelerated decoding
# todo: remove when nixpkgs electron default version is updated to 43+

{ ... }:

final: prev: {
  bilibili = prev.unstable.bilibili.override { electron = prev.unstable.electron_43; };
}
