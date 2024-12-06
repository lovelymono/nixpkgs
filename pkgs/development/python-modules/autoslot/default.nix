{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  flit-core,
  pytestCheckHook,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "autoslot";
  version = "2024.12.1";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "cjrh";
    repo = "autoslot";
    rev = "refs/tags/v${version}";
    hash = "sha256-wYjsBrjvSZFHDt0HLrnS9Xwk8EHVQupfPSkQnUFmMAk=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace 'requires = ["flit"]' 'requires = ["flit_core"]' \
      --replace 'build-backend = "flit.buildapi"' 'build-backend = "flit_core.buildapi"'
  '';

  nativeBuildInputs = [ flit-core ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "autoslot" ];

  meta = with lib; {
    description = "Automatic __slots__ for your Python classes";
    homepage = "https://github.com/cjrh/autoslot";
    license = licenses.asl20;
    maintainers = with maintainers; [ fab ];
  };
}
