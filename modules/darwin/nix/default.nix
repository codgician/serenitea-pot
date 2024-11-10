{ ... }: {
  config.nix = {
    gc.interval = {
      Hour = 2;
      Minute = 0;
    };

    optimise.interval = {
      Hour = 2;
      Minute = 30;
    };

    linux-builder = {
      enable = true;
      ephemeral = true;
    };
  };
}
