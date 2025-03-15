{
  lib,
  gccStdenv,
  fetchzip,
  pkgs,
  boost,
  cmake,
  jq,
  ncurses,
  python3,
  versionCheckHook,
  z3Support ? true,
  z3 ? null,
  cvc4Support ? gccStdenv.hostPlatform.isLinux,
  cvc4 ? null,
  cln ? null,
  gmp ? null,
}:

# compiling source/libsmtutil/CVC4Interface.cpp breaks on clang on Darwin,
# general commandline tests fail at abiencoderv2_no_warning/ on clang on NixOS
assert z3Support -> z3 != null && lib.versionAtLeast z3.version "4.11.0";
assert cvc4Support -> cvc4 != null && cln != null && gmp != null;

let
  pname = "solc";

  version = "0.8.28";
  linuxHash = "sha256-kosJ10stylGK5NUtsnMM7I+OfhR40TXPQDvnggOFLLc=";
  darwinHash = "sha256-gVFbDlPeqiZtVJVFzKrApalubU6CAcd/ZzsscQl22eo=";

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = [ "--version" ];
  doInstallCheck = true;

  meta = {
    description = "Compiler for Ethereum smart contract language Solidity";
    homepage = "https://github.com/ethereum/solidity";
    changelog = "https://github.com/ethereum/solidity/releases/tag/v${version}";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [
      dbrock
      akru
      lionello
      sifmelcara
    ];
  };

  solc =
    if gccStdenv.hostPlatform.isLinux then
      gccStdenv.mkDerivation rec {
        inherit
          pname
          version
          nativeInstallCheckInputs
          versionCheckProgramArg
          doInstallCheck
          meta
          ;

        # upstream suggests avoid using archive generated by github
        src = fetchzip {
          url = "https://github.com/ethereum/solidity/releases/download/v${version}/solidity_${version}.tar.gz";
          hash = linuxHash;
        };

        # Fix build with GCC 14
        # Submitted upstream: https://github.com/ethereum/solidity/pull/15685
        postPatch = ''
          substituteInPlace test/yulPhaser/Chromosome.cpp \
            --replace-fail \
              "BOOST_TEST(abs" \
              "BOOST_TEST(fabs"
        '';

        cmakeFlags =
          [
            "-DBoost_USE_STATIC_LIBS=OFF"

          ]
          ++ (
            if z3Support then
              [
                "-DSTRICT_Z3_VERSION=OFF"
              ]
            else
              [
                "-DUSE_Z3=OFF"
              ]
          )
          ++ lib.optionals (!cvc4Support) [
            "-DUSE_CVC4=OFF"
          ];

        nativeBuildInputs = [ cmake ];
        buildInputs =
          [ boost ]
          ++ lib.optionals z3Support [ z3 ]
          ++ lib.optionals cvc4Support [
            cvc4
            cln
            gmp
          ];
        nativeCheckInputs = [
          jq
          ncurses
          (python3.withPackages (
            ps: with ps; [
              colorama
              deepdiff
              devtools
              docopt
              docutils
              requests
              sphinx
              tabulate
              z3-solver
            ]
          ))
        ]; # contextlib2 glob2 textwrap3 traceback2 urllib3

        enableParallelBuilding = true;

        # tests take 60+ minutes to complete, only run as part of passthru tests
        doCheck = false;

        checkPhase = ''
          pushd ..
          # IPC tests need aleth avaliable, so we disable it
          sed -i "s/IPC_ENABLED=true/IPC_ENABLED=false\nIPC_FLAGS=\"--no-ipc\"/" ./scripts/tests.sh
          for i in ./scripts/*.sh ./scripts/*.py ./test/*.sh ./test/*.py; do
            patchShebangs "$i"
          done
          ## TODO: reenable tests below after adding evmone and hera and their dependencies to nixpkgs
          #TERM=xterm ./scripts/tests.sh ${lib.optionalString z3Support "--no-smt"}
          popd
        '';

        installCheckPhase = ''
          runHook preInstallCheck

          $out/bin/solc --version > /dev/null

          runHook postInstallCheck
        '';

        passthru.tests = {
          solcWithTests = solc.overrideAttrs (attrs: {
            doCheck = true;
          });
        };
      }
    else
      gccStdenv.mkDerivation rec {
        inherit
          pname
          version
          nativeInstallCheckInputs
          versionCheckProgramArg
          doInstallCheck
          meta
          ;

        src = pkgs.fetchurl {
          url = "https://github.com/ethereum/solidity/releases/download/v${version}/solc-macos";
          hash = darwinHash;
        };
        dontUnpack = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          cp ${src} $out/bin/solc
          chmod +x $out/bin/solc

          runHook postInstall
        '';
      };
in
solc
