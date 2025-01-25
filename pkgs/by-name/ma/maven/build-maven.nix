{
  stdenv,
  maven,
  runCommand,
  writeText,
  fetchurl,
  lib,
  requireFile,
  linkFarm,
}:
# Takes an info file generated by mvn2nix
# (https://github.com/NixOS/mvn2nix-maven-plugin) and builds the maven
# project with it.
#
# repo: A local maven repository with the project's dependencies.
#
# settings: A settings.xml to pass to maven to use the repo.
#
# build: A simple build derivation that uses mvn compile and package to build
#        the project.
#
# @example
#     project = pkgs.buildMaven ./project-info.json
infoFile:
let
  info = lib.importJSON infoFile;

  dependencies = lib.flatten (
    map (
      dep:
      let
        inherit (dep)
          sha1
          groupId
          artifactId
          version
          metadata
          repository-id
          ;
        versionDir = dep.unresolved-version or version;
        authenticated = dep.authenticated or false;
        url = dep.url or "";

        fetch =
          if (url != "") then
            ((if authenticated then requireFile else fetchurl) {
              inherit url sha1;
            })
          else
            "";

        fetchMetadata = (if authenticated then requireFile else fetchurl) {
          inherit (metadata) url sha1;
        };

        layout = "${builtins.replaceStrings [ "." ] [ "/" ] groupId}/${artifactId}/${versionDir}";
      in
      lib.optional (url != "") {
        layout = "${layout}/${fetch.name}";
        drv = fetch;
      }
      ++ lib.optionals (dep ? metadata) (
        [
          {
            layout = "${layout}/maven-metadata-${repository-id}.xml";
            drv = fetchMetadata;
          }
        ]
        ++ lib.optional (fetch != "") {
          layout = "${layout}/${builtins.replaceStrings [ version ] [ dep.unresolved-version ] fetch.name}";
          drv = fetch;
        }
      )
    ) info.dependencies
  );

  repo = linkFarm "maven-repository" (
    lib.forEach dependencies (dependency: {
      name = dependency.layout;
      path = dependency.drv;
    })
  );

  settings = writeText "settings.xml" ''
    <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                          http://maven.apache.org/xsd/settings-1.0.0.xsd">
      <localRepository>${repo}</localRepository>
    </settings>
  '';

  src = dirOf infoFile;
in
{
  inherit repo settings info;

  build = stdenv.mkDerivation {
    name = "${info.project.artifactId}-${info.project.version}.jar";

    src = builtins.filterSource (
      path: type:
      (toString path) != (toString (src + "/target")) && (toString path) != (toString (src + "/.git"))
    ) src;

    buildInputs = [ maven ];

    buildPhase = "mvn --offline --settings ${settings} compile";

    installPhase = ''
      mvn --offline --settings ${settings} package
      mv target/*.jar $out
    '';
  };
}
