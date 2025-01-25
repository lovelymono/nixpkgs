{
  callPackage,
  fetchurl,

  # This is a bit unusual, but makes version and hash easily
  # overridable. This is useful when people have an older version of
  # Softmaker Office or when the upstream archive was replaced and
  # nixpkgs is not in sync yet.
  officeVersion ? {
    version = "1222";
    edition = "2024";
    hash = "sha256-eyYBK5ZxPcBakOvXUQZIU2aftyH6PXh/rtqC/1BJhg4=";
  },

  ...
}@args:

callPackage ./generic.nix (
  args
  // rec {
    inherit (officeVersion) version edition;

    pname = "softmaker-office";
    suiteName = "SoftMaker Office";

    src = fetchurl {
      inherit (officeVersion) hash;
      url = "https://www.softmaker.net/down/softmaker-office-${edition}-${version}-amd64.tgz";
    };

    archive = "office${edition}.tar.lzma";
  }
)
