{
  lib,
  stdenvNoCC,
  python3,
  git,
}:
stdenvNoCC.mkDerivation {
  pname = "remote-agy-gitea-sidecar";
  version = "1.0.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./gitea-sidecar.py
      ./test_gitea_sidecar.py
    ];
  };
  buildInputs = [ python3 ];
  nativeCheckInputs = [
    python3
    git
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -m unittest -v test_gitea_sidecar.py
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 gitea-sidecar.py "$out/bin/remote-agy-gitea-sidecar"
    runHook postInstall
  '';
}
