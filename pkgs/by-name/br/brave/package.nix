# Expression generated by update.sh; do not edit it by hand!
{ stdenv, callPackage, ... }@args:

let
  pname = "brave";
  version = "1.74.50";

  allArchives = {
    aarch64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_arm64.deb";
      hash = "sha256-vit57iZLBp1wP4SK8nqqZRaCHlxwgMRo2MXHVvw8apk=";
    };
    x86_64-linux = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
      hash = "sha256-XnaDaJaqjPOXSXaShia6Ooyn/DegU0vC0XefjBoX6zE=";
    };
    aarch64-darwin = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-v${version}-darwin-arm64.zip";
      hash = "sha256-9fke4rkaXWO5e9GBF+hdiDUjST8OsYJQ8tHxE5kJAcc=";
    };
    x86_64-darwin = {
      url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-v${version}-darwin-x64.zip";
      hash = "sha256-TwBmR7LlGZlpgIDJ2ShAS5uHwTh8dHvRONJln7Z9rgs=";
    };
  };

  archive =
    if builtins.hasAttr stdenv.system allArchives then
      allArchives.${stdenv.system}
    else
      throw "Unsupported platform.";

in
callPackage ./make-brave.nix (removeAttrs args [ "callPackage" ]) (
  archive
  // {
    inherit pname version;
  }
)
