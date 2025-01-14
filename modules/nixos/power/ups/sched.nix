{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.codgician.power.ups;
  upssched-cmd = pkgs.writeShellApplication {
    name = "upssched-cmd";
    runtimeInputs = with pkgs; [
      nut
      util-linux
    ];
    text = ''
      log_event () {
        logger -t upssched-cmd "$1"
      }

      case $1 in
        upsgone)
          log_event "The UPS has been gone for a while"
          ;;
        replacebat)
          log_event "The UPS needs its battery replaced"
          ;;
        lowbat)
          log_event "The UPS has LOW BAT"
          upsmon -c fsd
          ;;
        onbatt)
          log_event "The UPS is ON BATT"
          ;;
        online)
          log_event  "The UPS is ONLINE"
          ;;
        timeonbatt)
          log_event "The UPS is ON BAT for a while"
          upsmon -c fsd
          ;;
        timeonline)
          log_event "The UPS is back ONLINE"
          ;;
        *)
          log_event "Unrecognized command: $1"
          ;;
      esac
    '';
  };
in
pkgs.writeText "upssched.conf" ''
  CMDSCRIPT ${upssched-cmd}
  PIPEFN /var/lib/nut/upssched.pipe
  LOCKFN /var/lib/nut/upssched.lock
  AT ONBATT * EXECUTE onbatt
  AT ONLINE * EXECUTE online
  ${lib.optionalString (cfg.sched.shutdownTimer > 0) ''
    AT ONBATT * START-TIMER timeonbatt ${toString cfg.sched.shutdownTimer}
    AT ONLINE * CANCEL-TIMER timeonbatt timeonline
  ''}
  AT COMMBAD * EXECUTE upsgone
  AT NOCOMM * EXECUTE upsgone
  AT REPLBATT * EXECUTE replacebat
  AT LOWBATT * EXECUTE lowbat
''
