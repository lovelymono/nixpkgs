{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  testers,
  okteto,
}:

buildGoModule rec {
  pname = "okteto";
  version = "3.2.1";

  src = fetchFromGitHub {
    owner = "okteto";
    repo = "okteto";
    rev = version;
    hash = "sha256-h8iDTxdcmczmc1THfl4Kwb67fZgzztw0SCHvhF4HdSQ=";
  };

  vendorHash = "sha256-/V95521PFvLACuXVjqsW3TEHHGQYKY8CSAOZ6FwuR0k=";

  postPatch = ''
    # Disable some tests that need file system & network access.
    find cmd -name "*_test.go" | xargs rm -f
    rm -f pkg/analytics/track_test.go
  '';

  nativeBuildInputs = [ installShellFiles ];

  excludedPackages = [
    "integration"
    "samples"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/okteto/okteto/pkg/config.VersionString=${version}"
  ];

  tags = [
    "osusergo"
    "netgo"
    "static_build"
  ];

  preCheck = ''
    export HOME="$(mktemp -d)"
  '';

  checkFlags =
    let
      skippedTests = [
        # require network access
        "TestCreateDockerfile"

        # access file system
        "Test_translateDeployment"
        "Test_translateStatefulSet"
        "Test_translateJobWithoutVolumes"
        "Test_translateJobWithVolumes"
        "Test_translateService"
      ];
    in
    [ "-skip=^${builtins.concatStringsSep "$|^" skippedTests}$" ];

  postInstall = ''
    installShellCompletion --cmd okteto \
      --bash <($out/bin/okteto completion bash) \
      --fish <($out/bin/okteto completion fish) \
      --zsh <($out/bin/okteto completion zsh)
  '';

  passthru.tests.version = testers.testVersion {
    package = okteto;
    command = "HOME=\"$(mktemp -d)\" okteto version";
  };

  meta = {
    description = "Develop your applications directly in your Kubernetes Cluster";
    homepage = "https://okteto.com/";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ aaronjheng ];
    mainProgram = "okteto";
  };
}
