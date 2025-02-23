{
  lib,
  ale-py,
  buildPythonPackage,
  cython,
  deepdiff,
  docstring-parser,
  fetchFromGitHub,
  gymnasium,
  h5py,
  imageio,
  joblib,
  jsonargparse,
  matplotlib,
  mujoco,
  numba,
  numpy,
  opencv,
  overrides,
  packaging,
  pandas,
  pettingzoo,
  poetry-core,
  pybox2d,
  pybullet,
  pygame,
  pymunk,
  pytestCheckHook,
  pythonOlder,
  scipy,
  sensai-utils,
  shimmy,
  swig,
  tensorboard,
  torch,
  tqdm,
}:

buildPythonPackage rec {
  pname = "tianshou";
  version = "1.1.0";
  pyproject = true;

  disabled = pythonOlder "3.11";

  src = fetchFromGitHub {
    owner = "thu-ml";
    repo = "tianshou";
    tag = "v${version}";
    hash = "sha256-eiwbSX8Q3KF6h7CfjuZ+7HlXwpvLga1NVr3e+FkPaHc=";
  };

  pythonRelaxDeps = [
    "deepdiff"
    "gymnasium"
    "numpy"
  ];

  pythonRemoveDeps = [ "virtualenv" ];

  postPatch = ''
    # silence matplotlib warning
    export MPLCONFIGDIR=$(mktemp -d)
  '';

  build-system = [ poetry-core ];

  dependencies = [
    deepdiff
    gymnasium
    h5py
    matplotlib
    numba
    numpy
    overrides
    packaging
    pandas
    pettingzoo
    sensai-utils
    tensorboard
    torch
    tqdm
  ];

  optional-dependencies = {
    all = lib.flatten (lib.attrValues (lib.filterAttrs (n: v: n != "all") optional-dependencies));

    argparse = [
      docstring-parser
      jsonargparse
    ];

    atari = [
      ale-py
      # autorom
      opencv
      shimmy
    ];

    box2d = [
      # instead of box2d-py
      pybox2d
      pygame
      swig
    ];

    classic_control = [
      pygame
    ];

    mujoco = [
      mujoco
      imageio
      cython
    ];

    pybullet = [
      pybullet
    ];

    # envpool = [
    #   envpool
    # ];

    # robotics = [
    #   gymnasium-robotics
    # ];

    # vizdoom = [
    #   vizdoom
    # ];

    eval = [
      docstring-parser
      joblib
      jsonargparse
      # rliable
      scipy
    ];
  };

  pythonImportsCheck = [ "tianshou" ];

  nativeCheckInputs = [
    pygame
    pymunk
    pytestCheckHook
  ];

  disabledTestPaths = [
    # remove tests that require lot of compute (ai model training tests)
    "test/continuous"
    "test/discrete"
    "test/highlevel"
    "test/modelbased"
    "test/offline"
  ];

  disabledTests = [
    # AttributeError: 'TimeLimit' object has no attribute 'test_attribute'
    "test_attr_unwrapped"
    # Failed: DID NOT RAISE <class 'TypeError'>
    "test_batch"
    # Failed: Raised AssertionError
    "test_vecenv"
  ];

  meta = with lib; {
    description = "Elegant PyTorch deep reinforcement learning library";
    homepage = "https://github.com/thu-ml/tianshou";
    changelog = "https://github.com/thu-ml/tianshou/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ derdennisop ];
  };
}
