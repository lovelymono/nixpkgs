{
  lib,
  stdenv,
  fetchurl,
  enableStatic ? with stdenv.hostPlatform; isStatic || isCygwin,
  enableShared ? true,
  autoreconfHook,
  testers,
}:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

stdenv.mkDerivation (
  finalAttrs:
  let
    inherit (finalAttrs) version;
  in
  {
    pname = "bzip2";
    version = "1.0.8";

    src = fetchurl {
      url = "https://sourceware.org/pub/bzip2/bzip2-${version}.tar.gz";
      sha256 = "sha256-q1oDF27hBtPw+pDjgdpHjdrkBZGBU8yiSOaCzQxKImk=";
    };

    patchFlags = [ "-p0" ];

    patches = [
      (fetchurl {
        url = "ftp://ftp.suse.com/pub/people/sbrabec/bzip2/for_downstream/bzip2-1.0.6.2-autoconfiscated.patch";
        sha256 = "sha256-QMufl6ffJVVVVZespvkCbFpB6++R1lnq1687jEsUjr0=";
      })
    ];
    # Fix up hardcoded version from the above patch, e.g. seen in bzip2.pc or libbz2.so.1.0.N
    postPatch = ''
      patch <<-EOF
        --- configure.ac
        +++ configure.ac
        @@ -3,3 +3,3 @@
        -AC_INIT([bzip2], [1.0.6], [Julian Seward <jseward@bzip.org>])
        +AC_INIT([bzip2], [${version}], [Julian Seward <jseward@bzip.org>])
         BZIP2_LT_CURRENT=1
        -BZIP2_LT_REVISION=6
        +BZIP2_LT_REVISION=${lib.versions.patch version}
      EOF
    '';

    strictDeps = true;
    nativeBuildInputs = [ autoreconfHook ];

    outputs = [
      "bin"
      "dev"
      "out"
      "man"
    ];

    configureFlags = lib.concatLists [
      (lib.optional enableStatic "--enable-static")
      (lib.optional (!enableShared) "--disable-shared")
    ];

    dontDisableStatic = enableStatic;

    enableParallelBuilding = true;

    postInstall = ''
      ln -s $out/lib/libbz2.so.1.0.* $out/lib/libbz2.so.1.0
    '';

    passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

    meta = with lib; {
      description = "High-quality data compression program";
      homepage = "https://www.sourceware.org/bzip2";
      changelog = "https://sourceware.org/git/?p=bzip2.git;a=blob;f=CHANGES;hb=HEAD";
      license = licenses.bsdOriginal;
      pkgConfigModules = [ "bzip2" ];
      platforms = platforms.all;
      maintainers = with maintainers; [ mic92 ];
    };
  }
)
