{ ... }: {
  config.nix = {
    gc = {
      persistent = true;
      dates = "02:00";
    };

    optimise.dates = [ "02:30" ];
  };
}
