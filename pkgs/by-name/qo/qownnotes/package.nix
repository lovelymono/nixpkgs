{
  lib,
  stdenv,
  fetchurl,
  qt6Packages,
  cmake,
  makeWrapper,
  botan2,
  pkg-config,
  nixosTests,
  installShellFiles,
  xvfb-run,
}:

let
  pname = "qownnotes";
  appname = "QOwnNotes";
  version = "25.1.6";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/pbek/QOwnNotes/releases/download/v${version}/qownnotes-${version}.tar.xz";
    hash = "sha256-EmkOuxXH7XSpWrw3rtLPQ4XCX93RDbhnUR1edsNVJLk=";
  };

  nativeBuildInputs =
    [
      cmake
      qt6Packages.qttools
      qt6Packages.wrapQtAppsHook
      pkg-config
      installShellFiles
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ xvfb-run ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ makeWrapper ];

  buildInputs = [
    qt6Packages.qtbase
    qt6Packages.qtdeclarative
    qt6Packages.qtsvg
    qt6Packages.qtwebsockets
    botan2
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [ qt6Packages.qtwayland ];

  cmakeFlags = [
    "-DQON_QT6_BUILD=ON"
    "-DBUILD_WITH_SYSTEM_BOTAN=ON"
  ];

  # Install shell completion on Linux (with xvfb-run)
  postInstall =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      installShellCompletion --cmd ${appname} \
        --bash <(xvfb-run $out/bin/${appname} --completion bash) \
        --fish <(xvfb-run $out/bin/${appname} --completion fish)
      installShellCompletion --cmd ${pname} \
        --bash <(xvfb-run $out/bin/${appname} --completion bash) \
        --fish <(xvfb-run $out/bin/${appname} --completion fish)
    ''
    # Install shell completion on macOS
    + lib.optionalString stdenv.isDarwin ''
      installShellCompletion --cmd ${pname} \
        --bash <($out/bin/${appname} --completion bash) \
        --fish <($out/bin/${appname} --completion fish)
    ''
    # Create a lowercase symlink for Linux
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      ln -s $out/bin/${appname} $out/bin/${pname}
    ''
    # Rename application for macOS as lowercase binary
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      # Prevent "same file" error
      mv $out/bin/${appname} $out/bin/${pname}.bin
      mv $out/bin/${pname}.bin $out/bin/${pname}
    '';

  # Tests QOwnNotes using the NixOS module by launching xterm:
  passthru.tests.basic-nixos-module-functionality = nixosTests.qownnotes;

  meta = {
    description = "Plain-text file notepad and todo-list manager with markdown support and Nextcloud/ownCloud integration";
    homepage = "https://www.qownnotes.org/";
    changelog = "https://www.qownnotes.org/changelog.html";
    downloadPage = "https://github.com/pbek/QOwnNotes/releases/tag/v${version}";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [
      pbek
      totoroot
      matthiasbeyer
    ];
    platforms = lib.platforms.unix;
  };
}
