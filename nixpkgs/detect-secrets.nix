{ lib
, buildPythonPackage
, fetchFromGitHub
, isPy27
, pyyaml
, requests
}:

buildPythonPackage
rec {
  pname = "detect-secrets";
  version = "1.1.2";
  disabled = isPy27;

  src = fetchFromGitHub {
    owner = "Contrast-Labs";
    repo = pname;
    rev = "7ed02347560610f3a2c963c0782a1aa853c6cde8";
    sha256 = "1l35wf4xchmg7qnm4i93kpqxjk50k04v3kff03dqvga34wqac4jx";
  };

  propagatedBuildInputs = [
    pyyaml
    requests
  ];

  meta = with lib; {
    description = "An enterprise friendly way of detecting and preventing secrets in code";
    homepage = "https://github.com/Contrast-Labs/detect-secrets";
    license = licenses.asl20;
  };
}
