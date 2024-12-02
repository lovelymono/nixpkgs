{
  lib,
  buildPythonPackage,
  pythonOlder,
  fetchFromGitHub,
  setuptools,
  aiohttp,
  bcrypt,
  freezegun,
  homeassistant,
  pytest-asyncio,
  pytest-socket,
  requests-mock,
  respx,
  syrupy,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "pytest-homeassistant-custom-component";
  version = "0.13.180";
  pyproject = true;

  disabled = pythonOlder "3.12";

  src = fetchFromGitHub {
    owner = "MatthewFlamm";
    repo = "pytest-homeassistant-custom-component";
    rev = "refs/tags/${version}";
    hash = "sha256-OLCGoZ5C39D4yYJagowO914qJlQcJVScm/a1ZbR2alM=";
  };

  build-system = [ setuptools ];

  pythonRemoveDeps = true;

  dependencies = [
    aiohttp
    bcrypt
    freezegun
    homeassistant
    pytest-asyncio
    pytest-socket
    requests-mock
    respx
    syrupy
  ];

  pythonImportsCheck = [ "pytest_homeassistant_custom_component.plugins" ];

  nativeCheckInputs = [ pytestCheckHook ];

  meta = {
    changelog = "https://github.com/MatthewFlamm/pytest-homeassistant-custom-component/blob/${src.rev}/CHANGELOG.md";
    description = "Package to automatically extract testing plugins from Home Assistant for custom component testing";
    homepage = "https://github.com/MatthewFlamm/pytest-homeassistant-custom-component";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ dotlambda ];
  };
}
