{
  lib,
  buildPythonPackage,
  fetchPypi,
  cython,
  setuptools,
  pytestCheckHook,
  hypothesis,
  readme-renderer,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "marisa-trie";
  version = "1.2.1";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchPypi {
    pname = "marisa_trie";
    inherit version;
    hash = "sha256-OifECOKu/APg8dJbL/KvuFqsNWj2+iripTtXouh84p0=";
  };

  build-system = [
    cython
    setuptools
  ];

  nativeCheckInputs = [
    pytestCheckHook
    readme-renderer
    hypothesis
  ];

  postPatch = ''
    substituteInPlace setup.py \
      --replace "hypothesis==" "hypothesis>="
  '';

  preBuild = ''
    ./update_cpp.sh
  '';

  disabledTestPaths = [
    # Don't test packaging
    "tests/test_packaging.py"
  ];

  disabledTests = [
    # Pins hypothesis==2.0.0 from 2016/01 which complains about
    # hypothesis.errors.FailedHealthCheck: tests/test_trie.py::[...] uses
    # the 'tmpdir' fixture, which is reset between function calls but not
    # between test cases generated by `@given(...)`.
    "test_saveload"
    "test_mmap"
  ];

  pythonImportsCheck = [ "marisa_trie" ];

  meta = with lib; {
    description = "Static memory-efficient Trie-like structures for Python based on marisa-trie C++ library";
    longDescription = ''
      There are official SWIG-based Python bindings included in C++ library distribution.
      This package provides alternative Cython-based pip-installable Python bindings.
    '';
    homepage = "https://github.com/kmike/marisa-trie";
    changelog = "https://github.com/pytries/marisa-trie/blob/${version}/CHANGES.rst";
    license = licenses.mit;
  };
}
