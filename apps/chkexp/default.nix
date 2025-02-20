{ lib, pkgs, ... }:

let
  thresholdInDays = 30;
  nearestExpiryDate = lib.pipe (import (lib.codgician.secretsDir + "/secrets.nix")) [
    builtins.attrValues
    (builtins.filter (x: x ? expiryDates))
    (builtins.concatMap (x: x.expiryDates))
    (builtins.foldl' lib.min "9999-12-31")
  ];
in
# Check expiry for secrets
{
  type = "app";
  meta = {
    description = "Utility that checks expiry for secrets";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [ coreutils ];

      text = ''
        current_time=$(date +%s)
        nearest_expiry_time=$(date -d "${nearestExpiryDate} 00:00:00" +%s)
        expiry_threshold=${builtins.toString (thresholdInDays * 24 * 60 * 60)}

        echo "Nearest expiry date: ${nearestExpiryDate}"
        if (( nearest_expiry_time >= (current_time + expiry_threshold) )); then
          echo "All secrets are far from expiry."
          exit 0
        else
          echo "At least one secret is near expiry (within ${builtins.toString thresholdInDays} days)."
          exit 1
        fi
      '';
    }
  );
}
