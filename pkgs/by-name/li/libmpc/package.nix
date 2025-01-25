{ lib, stdenv, fetchurl
, gmp, mpfr
, updateAutotoolsGnuConfigScriptsHook
}:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

stdenv.mkDerivation rec {
  pname = "libmpc";
  version = "1.3.1"; # to avoid clash with the MPD client

  src = fetchurl {
    url = "mirror://gnu/mpc/mpc-${version}.tar.gz";
    sha256 = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
  };

  strictDeps = true;
  enableParallelBuilding = true;

  buildInputs = [ gmp mpfr ];
  nativeBuildInputs = [
    # needed until config scripts are updated to not use /usr/bin/uname on FreeBSD native
    updateAutotoolsGnuConfigScriptsHook
  ];

  doCheck = true; # not cross;

  meta = {
    description = "Library for multiprecision complex arithmetic with exact rounding";

    longDescription = ''
      GNU MPC is a C library for the arithmetic of complex numbers with
      arbitrarily high precision and correct rounding of the result.  It is
      built upon and follows the same principles as GNU MPFR.
    '';

    homepage = "https://www.multiprecision.org/mpc/";
    license = lib.licenses.lgpl2Plus;

    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
