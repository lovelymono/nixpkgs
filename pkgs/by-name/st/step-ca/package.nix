{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
  coreutils,
  pcsclite,
  pkg-config,
  hsmSupport ? true,
  nixosTests,
  darwin,
}:

buildGoModule rec {
  pname = "step-ca";
  version = "0.28.0";

  src = fetchFromGitHub {
    owner = "smallstep";
    repo = "certificates";
    rev = "refs/tags/v${version}";
    hash = "sha256-FmhfsfRq6pxDhGDsNqY2IQczHk8NYEdxNaN2hfbhDYw=";
  };

  vendorHash = "sha256-ZziypdQJaQHdL5/bcX6P5VHGVtbcl+twtlOg7DlmLZM=";

  ldflags = [
    "-w"
    "-X main.Version=${version}"
  ];

  nativeBuildInputs = lib.optionals hsmSupport [ pkg-config ];

  buildInputs =
    lib.optionals (hsmSupport && stdenv.hostPlatform.isLinux) [ pcsclite ]
    ++ lib.optionals (hsmSupport && stdenv.hostPlatform.isDarwin) [ darwin.apple_sdk.frameworks.PCSC ];
  postPatch = ''
    substituteInPlace authority/http_client_test.go --replace-fail 't.Run("SystemCertPool", func(t *testing.T) {' 't.Skip("SystemCertPool", func(t *testing.T) {'
    substituteInPlace systemd/step-ca.service --replace "/bin/kill" "${coreutils}/bin/kill"
  '';

  preBuild = ''
    ${lib.optionalString (!hsmSupport) "export CGO_ENABLED=0"}
  '';

  postInstall = ''
    install -Dm444 -t $out/lib/systemd/system systemd/step-ca.service
  '';

  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  # Tests start http servers which need to bind to local addresses:
  # panic: httptest: failed to listen on a port: listen tcp6 [::1]:0: bind: operation not permitted
  __darwinAllowLocalNetworking = true;

  # Tests need to run in a reproducible order, otherwise they run unreliably on
  # (at least) x86_64-linux.
  checkFlags = [ "-p 1" ];

  passthru.tests.step-ca = nixosTests.step-ca;

  meta = with lib; {
    description = "Private certificate authority (X.509 & SSH) & ACME server for secure automated certificate management, so you can use TLS everywhere & SSO for SSH";
    homepage = "https://smallstep.com/certificates/";
    changelog = "https://github.com/smallstep/certificates/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [
      cmcdragonkai
      techknowlogick
    ];
  };
}
