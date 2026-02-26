# Parse systemd credential file to extract PCR bank algorithm
#
# The hash_alg field is at a fixed offset in TPM2 credentials:
#   - Main header: 48 bytes (16 uuid + 16 sizes + 12 iv + 4 padding)
#   - TPM2 header: pcr_mask (8 bytes), then hash_alg (2 bytes)
#   - Total offset: 56 bytes
#
# TPM2 algorithm IDs (little-endian):
#   0x0004 = SHA1, 0x000B = SHA256, 0x000C = SHA384, 0x000D = SHA512
{ pkgs }:

let
  parseCredentialPcrBank =
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
    .${builtins.readFile algByte} or (throw "Unknown PCR bank in ${credFile}");
in
{
  inherit parseCredentialPcrBank;
}
