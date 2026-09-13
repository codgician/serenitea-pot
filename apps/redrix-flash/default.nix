{ lib, pkgs, ... }:
let
  firmware = pkgs.unstable.nur.repos.codgician;
  application = pkgs.writeShellApplication {
    name = "redrix-flash";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gnugrep
      gnused
      util-linux
      systemd
      flashrom
      cbfstool
      ifdtool
      fw-ectool
    ];
    text =
      lib.replaceStrings
        [ "@ecFirmware@" "@corebootFirmware@" ]
        [
          "${firmware.redrix-ec}/share/firmware/redrix-ec"
          "${firmware.redrix-coreboot}/share/firmware/redrix-coreboot"
        ]
        (builtins.readFile ./redrix-flash.sh);
  };
in
{
  type = "app";
  meta = {
    description = "Back up and update Redrix EC RW and coreboot firmware";
    platforms = [ "x86_64-linux" ];
  };
  program = lib.getExe (
    pkgs.writeShellApplication {
      name = "redrix-flash";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        case "''${1:-status}" in
          status|--help|-h) exec ${lib.getExe application} "$@" ;;
          *) exec systemd-inhibit --what=sleep:shutdown:handle-lid-switch --mode=block \
            --who=redrix-flash --why='Redrix firmware update' \
            ${lib.getExe application} "$@" ;;
        esac
      '';
    }
  );
}
