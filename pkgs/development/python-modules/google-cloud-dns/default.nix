{
  lib,
  buildPythonPackage,
  fetchPypi,
  google-api-core,
  google-cloud-core,
  mock,
  pytestCheckHook,
  pythonOlder,
  setuptools,
}:

buildPythonPackage rec {
  pname = "google-cloud-dns";
  version = "0.35.0";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-CsRNqesPoLEilRPNiIB0q9AhGZLEBCMAr9HBbUFHRVM=";
  };

  build-system = [ setuptools ];

  dependencies = [
    google-api-core
    google-cloud-core
  ];

  nativeCheckInputs = [
    mock
    pytestCheckHook
  ];

  preCheck = ''
    # don#t shadow python imports
    rm -r google
  '';

  disabledTests = [
    # Test requires credentials
    "test_quota"
  ];

  pythonImportsCheck = [ "google.cloud.dns" ];

  meta = with lib; {
    description = "Google Cloud DNS API client library";
    homepage = "https://github.com/googleapis/python-dns";
    changelog = "https://github.com/googleapis/python-dns/blob/v${version}/CHANGELOG.md";
    license = licenses.asl20;
    maintainers = [ ];
  };
}
