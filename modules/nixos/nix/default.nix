{ ... }: {
  config.nix = {
    gc = {
      persistent = true;
      dates = "02:00";
    };
  };
}
