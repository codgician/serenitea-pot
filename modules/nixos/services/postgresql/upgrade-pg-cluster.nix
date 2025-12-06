# Reference: https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading

{ config, pkgs, ... }:
let
  cfg = config.codgician.services.postgresql;
  newPostgres = pkgs.postgresql.withPackages config.services.postgresql.extensions;
  oldPostgres = config.services.postgresql.package.withPackages config.services.postgresql.extensions;
  user = "postgres";
  group = "postgres";
in
pkgs.writeShellApplication {
  name = "upgrade-pg-cluster";
  runtimeInputs = with pkgs; [
    coreutils
    systemd
  ];
  text = ''
    set -eux
    # XXX it's perhaps advisable to stop all services that depend on postgresql
    systemctl stop postgresql.service

    export NEWDATA="${cfg.dataDir}/${newPostgres.psqlSchema}"
    export NEWBIN="${newPostgres}/bin"
    export OLDDATA="${config.services.postgresql.dataDir}"
    export OLDBIN="${oldPostgres}/bin"

    # install -d -m 0700 -o ${user} -g ${group} "$NEWDATA"
    mkdir -p "$NEWDATA"
    chmod -R 700 "$NEWDATA"
    chown -R ${user}:${group} "$NEWDATA"

    cd "$NEWDATA"
    sudo -u ${user} "$NEWBIN/initdb" -D "$NEWDATA"

    sudo -u ${user} "$NEWBIN/pg_upgrade" \
      --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
      --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
      "$@"

    echo "If everything goes well, the newly migrated data is located in ''${NEWDATA}."
    echo "Please manually backup the old data and overwrite it with migrated data."
  '';
}
