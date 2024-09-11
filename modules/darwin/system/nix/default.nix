{ ... }: {
  config = {
    # Enable nix daemon
    services.nix-daemon.enable = true;
  };
}
