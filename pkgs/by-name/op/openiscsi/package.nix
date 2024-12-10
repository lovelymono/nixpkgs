{
  stdenv,
  lib,
  fetchFromGitHub,
  meson,
  pkg-config,
  ninja,
  perl,
  util-linux,
  open-isns,
  openssl,
  kmod,
  systemd,
  runtimeShell,
  nixosTests,
}:

stdenv.mkDerivation rec {
  pname = "open-iscsi";
  version = "2.1.10";

  src = fetchFromGitHub {
    owner = "open-iscsi";
    repo = "open-iscsi";
    rev = version;
    hash = "sha256-5bT9MaJ2OHFU9R9X01UOOztRqtR6rWv4RS5d1MGWf6M=";
  };

  nativeBuildInputs = [
    meson
    pkg-config
    ninja
    perl
  ];
  buildInputs = [
    kmod
    open-isns
    openssl
    systemd
    util-linux
  ];

  preConfigure = ''
    patchShebangs .
  '';

  prePatch = ''
    substituteInPlace etc/systemd/iscsi-init.service.template \
      --replace /usr/bin/sh ${runtimeShell}
    sed -i '/install_dir: db_root/d' meson.build
  '';

  mesonFlags = [
    "-Discsi_sbindir=${placeholder "out"}/sbin"
    "-Drulesdir=${placeholder "out"}/etc/udev/rules.d"
    "-Dsystemddir=${placeholder "out"}/lib/systemd"
    "-Ddbroot=/etc/iscsi"
  ];

  passthru.tests = { inherit (nixosTests) iscsi-root; };

  meta = with lib; {
    description = "High performance, transport independent, multi-platform implementation of RFC3720";
    license = licenses.gpl2Plus;
    homepage = "https://www.open-iscsi.com";
    platforms = platforms.linux;
    maintainers = with maintainers; [
      cleverca22
      zaninime
    ];
  };
}
