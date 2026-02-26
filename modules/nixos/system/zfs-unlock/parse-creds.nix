# Extract PCR bank from systemd credential file at eval time
#
# TPM2 hash_alg at offset 56: 0x04=sha1, 0x0b=sha256, 0x0c=sha384, 0x0d=sha512
{ pkgs }:
credFile:
let
  algByte = pkgs.runCommand "parse-cred-pcr-bank" { } ''
    ${pkgs.coreutils}/bin/base64 -d < ${credFile} \
      | ${pkgs.coreutils}/bin/od -An -tx1 -j56 -N1 \
      | ${pkgs.coreutils}/bin/tr -d ' \n' > $out
  '';
in
{
  "04" = "sha1";
  "0b" = "sha256";
  "0c" = "sha384";
  "0d" = "sha512";
}
.${builtins.readFile algByte} or (throw "Unknown PCR bank in ${credFile}")
