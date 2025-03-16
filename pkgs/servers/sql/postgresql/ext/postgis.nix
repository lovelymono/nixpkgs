{
  autoconf,
  automake,
  cunit,
  docbook5,
  fetchFromGitHub,
  file,
  gdalMinimal,
  geos,
  jitSupport,
  json_c,
  lib,
  libiconv,
  libtool,
  libxml2,
  libxslt,
  llvm,
  pcre2,
  perl,
  pkg-config,
  postgresql,
  postgresqlBuildExtension,
  postgresqlTestExtension,
  postgresqlTestHook,
  proj,
  protobufc,
  stdenv,
  which,

  withSfcgal ? false,
  sfcgal,
}:

let
  gdal = gdalMinimal;
in
postgresqlBuildExtension (finalAttrs: {
  pname = "postgis";
  version = "3.5.2";

  outputs = [
    "out"
    "doc"
  ];

  src = fetchFromGitHub {
    owner = "postgis";
    repo = "postgis";
    tag = "${finalAttrs.version}";
    hash = "sha256-1kOLtG6AMavbWQ1lHG2ABuvIcyTYhgcbjuVmqMR4X+g=";
  };

  buildInputs =
    [
      geos
      proj
      gdal
      json_c
      protobufc
      pcre2.dev
    ]
    ++ lib.optional stdenv.hostPlatform.isDarwin libiconv
    ++ lib.optional withSfcgal sfcgal;

  nativeBuildInputs = [
    autoconf
    automake
    libtool
    libxml2
    perl
    pkg-config
    protobufc
    which
  ] ++ lib.optional jitSupport llvm;

  dontDisableStatic = true;

  nativeCheckInputs = [
    postgresqlTestHook
    cunit
    libxslt
  ];

  postgresqlTestUserOptions = "LOGIN SUPERUSER";
  failureHook = "postgresqlStop";

  # postgis config directory assumes /include /lib from the same root for json-c library
  env.NIX_LDFLAGS = "-L${lib.getLib json_c}/lib";

  setOutputFlags = false;
  preConfigure = ''
    ./autogen.sh
  '';

  configureFlags = [
    "--with-gdalconfig=${gdal}/bin/gdal-config"
    "--with-jsondir=${json_c.dev}"
    "--disable-extension-upgrades-install"
  ] ++ lib.optional withSfcgal "--with-sfcgal=${sfcgal}/bin/sfcgal-config";

  makeFlags = [
    "PERL=${perl}/bin/perl"
  ];

  doCheck = stdenv.hostPlatform.isLinux;

  preCheck = ''
    substituteInPlace doc/postgis-out.xml --replace-fail "http://docbook.org/xml/5.0/dtd/docbook.dtd" "${docbook5}/xml/dtd/docbook/docbookx.dtd"
    # The test suite hardcodes it to use /tmp.
    export PGIS_REG_TMPDIR="$TMPDIR/pgis_reg"
  '';

  # create aliases for all commands adding version information
  postInstall = ''
    for prog in $out/bin/*; do # */
      ln -s $prog $prog-${finalAttrs.version}
    done

    mkdir -p $doc/share/doc/postgis
    mv doc/* $doc/share/doc/postgis/
  '';

  passthru.tests.extension = postgresqlTestExtension {
    inherit (finalAttrs) finalPackage;
    sql =
      let
        expectedVersion = "${lib.versions.major finalAttrs.version}.${lib.versions.minor finalAttrs.version} USE_GEOS=1 USE_PROJ=1 USE_STATS=1";
      in
      ''
        CREATE EXTENSION postgis;
        CREATE EXTENSION postgis_raster;
        CREATE EXTENSION postgis_topology;
        select postgis_version();
        do $$
        begin
          if postgis_version() <> '${expectedVersion}' then
            raise '"%" does not match "${expectedVersion}"', postgis_version();
          end if;
        end$$;
        -- st_makepoint goes through c code
        select st_makepoint(1, 1);
      ''
      + lib.optionalString withSfcgal ''
        CREATE EXTENSION postgis_sfcgal;
        do $$
        begin
          if postgis_sfcgal_version() <> '${sfcgal.version}' then
            raise '"%" does not match "${sfcgal.version}"', postgis_sfcgal_version();
          end if;
        end$$;
        CREATE TABLE geometries (
          name varchar,
          geom geometry(PolygonZ) NOT NULL
        );

        INSERT INTO geometries(name, geom) VALUES
          ('planar geom', 'PolygonZ((1 1 0, 1 2 0, 2 2 0, 2 1 0, 1 1 0))'),
          ('nonplanar geom', 'PolygonZ((1 1 1, 1 2 -1, 2 2 2, 2 1 0, 1 1 1))');

        SELECT name from geometries where cg_isplanar(geom);
      '';
  };

  meta = {
    description = "Geographic Objects for PostgreSQL";
    homepage = "https://postgis.net/";
    changelog = "https://git.osgeo.org/gitea/postgis/postgis/raw/tag/${finalAttrs.version}/NEWS";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; lib.teams.geospatial.members ++ [ marcweber ];
    inherit (postgresql.meta) platforms;
  };
})
