{
  lib,
  src,
  python3Packages,
}:

python3Packages.buildPythonPackage {
  inherit src;
  pname = "pydvdid";
  version = "1.1";
  pyproject = true;
  build-system = with python3Packages; [
    setuptools
  ];
}
