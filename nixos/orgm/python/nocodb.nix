{
  buildPythonPackage,
  fetchPypi,
  requests,
  setuptools,
}:

buildPythonPackage rec {
  pname = "nocodb";
  version = "2.0.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-XNRNebvj8s39P82oDlNL8gjaKOjTFr6ch/BfgPuqhlw=";
  };

  build-system = [ setuptools ];
  dependencies = [ requests ];

  pythonImportsCheck = [ "nocodb" ];
}
