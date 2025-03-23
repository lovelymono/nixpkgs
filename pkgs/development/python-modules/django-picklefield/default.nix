{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  django,
  python,
}:

buildPythonPackage rec {
  pname = "django-picklefield";
  version = "3.3.0";
  format = "setuptools";

  # The PyPi source doesn't contain tests
  src = fetchFromGitHub {
    owner = "gintas";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-/H6spsf2fmJdg5RphD8a4YADggr+5d+twuLoFMfyEac=";
  };

  propagatedBuildInputs = [ django ];

  checkPhase = ''
    runHook preCheck
    ${python.interpreter} -m django test --settings=tests.settings
    runHook postCheck
  '';

  meta = with lib; {
    description = "Pickled object field for Django";
    homepage = "https://github.com/gintas/django-picklefield";
    license = licenses.mit;
    maintainers = [ ];
  };
}
