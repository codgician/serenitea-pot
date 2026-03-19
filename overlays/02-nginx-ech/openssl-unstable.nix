# OpenSSL 4.0.0-alpha1 with Encrypted Client Hello (ECH) support
#
# ECH (RFC 9849) encrypts the TLS handshake SNI field to protect user privacy.
# This is an alpha release - use with caution in production.
#
# Key changes from 3.x:
#   - ECH support enabled by default
#   - ENGINE API removed entirely
#   - ASN1_STRING and other structs made opaque
#   - Many X509 functions now return const pointers
#   - SSLv3 support removed
#   - Requires C-99 compiler

{ prev }:

prev.stdenv.mkDerivation (finalAttrs: {
  pname = "openssl-unstable";
  version = "4.0.0-alpha1";

  src = prev.fetchFromGitHub {
    owner = "openssl";
    repo = "openssl";
    rev = "openssl-${finalAttrs.version}";
    hash = "sha256-WDMfYXsqWF5r3aR9mQNNDTugppvtOU0Yc/BHKSFH6PE=";
  };

  postPatch = ''
    patchShebangs Configure
    substituteInPlace config --replace '/usr/bin/env' '${prev.buildPackages.coreutils}/bin/env'
  ''
  + prev.lib.optionalString prev.stdenv.hostPlatform.isMusl ''
    substituteInPlace crypto/async/arch/async_posix.h \
      --replace '!defined(__ANDROID__) && !defined(__OpenBSD__)' \
                '!defined(__ANDROID__) && !defined(__OpenBSD__) && 0'
  '';

  outputs = [
    "bin"
    "dev"
    "out"
    "man"
  ];

  setOutputFlags = false;
  separateDebugInfo =
    !prev.stdenv.hostPlatform.isDarwin
    && !prev.stdenv.hostPlatform.isAndroid
    && !(prev.stdenv.hostPlatform.useLLVM or false)
    && prev.stdenv.cc.isGNU;

  nativeBuildInputs =
    prev.lib.optional (!prev.stdenv.hostPlatform.isWindows) prev.makeBinaryWrapper
    ++ [ prev.perl ];

  configurePlatforms = [ ];
  configureScript =
    {
      armv5tel-linux = "./Configure linux-armv4 -march=armv5te";
      armv6l-linux = "./Configure linux-armv4 -march=armv6";
      armv7l-linux = "./Configure linux-armv4 -march=armv7-a";
      x86_64-darwin = "./Configure darwin64-x86_64-cc";
      aarch64-darwin = "./Configure darwin64-arm64-cc";
      x86_64-linux = "./Configure linux-x86_64";
      x86_64-solaris = "./Configure solaris64-x86_64-gcc";
      powerpc-linux = "./Configure linux-ppc";
      powerpc64-linux = "./Configure linux-ppc64";
      riscv32-linux = "./Configure linux32-riscv32";
      riscv64-linux = "./Configure linux64-riscv64";
    }
    .${prev.stdenv.hostPlatform.system} or (
      if prev.stdenv.hostPlatform == prev.stdenv.buildPlatform then
        "./config"
      else if prev.stdenv.hostPlatform.isBSD then
        if prev.stdenv.hostPlatform.isx86_64 then
          "./Configure BSD-x86_64"
        else if prev.stdenv.hostPlatform.isx86_32 then
          "./Configure BSD-x86" + prev.lib.optionalString prev.stdenv.hostPlatform.isElf "-elf"
        else
          "./Configure BSD-generic${toString prev.stdenv.hostPlatform.parsed.cpu.bits}"
      else if prev.stdenv.hostPlatform.isMinGW then
        "./Configure mingw${
          prev.lib.optionalString (prev.stdenv.hostPlatform.parsed.cpu.bits != 32) (
            toString prev.stdenv.hostPlatform.parsed.cpu.bits
          )
        }"
      else if prev.stdenv.hostPlatform.isLinux then
        if prev.stdenv.hostPlatform.isx86_64 then
          "./Configure linux-x86_64"
        else if prev.stdenv.hostPlatform.isMicroBlaze then
          "./Configure linux-latomic"
        else if prev.stdenv.hostPlatform.isMips32 then
          "./Configure linux-mips32"
        else if prev.stdenv.hostPlatform.isMips64n32 then
          "./Configure linux-mips64"
        else if prev.stdenv.hostPlatform.isMips64n64 then
          "./Configure linux64-mips64"
        else
          "./Configure linux-generic${toString prev.stdenv.hostPlatform.parsed.cpu.bits}"
      else if prev.stdenv.hostPlatform.isiOS then
        "./Configure ios${toString prev.stdenv.hostPlatform.parsed.cpu.bits}-cross"
      else
        throw "OpenSSL: unsupported platform ${prev.stdenv.hostPlatform.config}"
    );

  dontAddStaticConfigureFlags = true;
  configureFlags = [
    "shared"
    "--libdir=lib"
    "--openssldir=etc/ssl"
  ]
  ++ prev.lib.optional prev.stdenv.hostPlatform.isx86_64 "enable-ec_nistp_64_gcc_128"
  ++ prev.lib.optional prev.stdenv.hostPlatform.isLinux "enable-ktls"
  ++ prev.lib.optional prev.stdenv.hostPlatform.isAarch64 "no-afalgeng"
  ++ prev.lib.optional prev.stdenv.hostPlatform.isOpenBSD "no-devcryptoeng"
  ++ [ "disable-tests" ];

  makeFlags = [
    "MANDIR=$(man)/share/man"
    "MANSUFFIX=ssl"
  ];

  enableParallelBuilding = true;

  __darwinAllowLocalNetworking = true;

  postInstall = ''
    # Don't install static libraries when building shared
    if [ -n "$(echo $out/lib/*.so $out/lib/*.dylib $out/lib/*.dll)" ]; then
      rm -f "$out/lib/"*.a
    fi

    mkdir -p $bin
    mv $out/bin $bin/bin
  ''
  + prev.lib.optionalString (!prev.stdenv.hostPlatform.isWindows) ''
    # Create c_rehash wrapper (script removed in OpenSSL 4.0)
    makeWrapper $bin/bin/openssl $bin/bin/c_rehash --add-flags "rehash"
  ''
  + ''
    mkdir -p $dev/bin
    mv $bin/bin/c_rehash $dev/bin/c_rehash
    rmdir --ignore-fail-on-non-empty $out/bin || true
  '';

  postFixup = prev.lib.optionalString (!prev.stdenv.hostPlatform.isWindows) ''
    $bin/bin/openssl version
  '';

  meta = {
    homepage = "https://www.openssl.org/";
    changelog = "https://github.com/openssl/openssl/blob/openssl-${finalAttrs.version}/CHANGES.md";
    description = "OpenSSL 4.0 alpha with Encrypted Client Hello (ECH) support";
    license = prev.lib.licenses.asl20;
    platforms = prev.lib.platforms.all;
    mainProgram = "openssl";
  };
})
