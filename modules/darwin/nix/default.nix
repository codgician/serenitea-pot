{ ... }: {
  config.nix = {
    gc.interval = {
      Hour = 2;
      Minute = 0;
    };

    linux-builder = {
      enable = true;
      ephemeral = true;
    };
  };
}
