{ stdenv, lib, fetchurl, autoPatchelfHook }:

let
  version = "0.13.1";

  sources = {
    aarch64-darwin = {
      asset = "hunkdiff-darwin-arm64";
      hash = "sha256-5V/x5hGODpTIf0xzp84mVA972GoGPzpH+JeHoG2wjNY=";
    };
    x86_64-darwin = {
      asset = "hunkdiff-darwin-x64";
      hash = "sha256-xPHfdcPlOzC+N/UUN6q53fjNORxaLc863oANKU1HXOs=";
    };
    aarch64-linux = {
      asset = "hunkdiff-linux-arm64";
      hash = "sha256-KWEWZsWz8N3qeFkGKqCt6xceVxMEPUzqjGOxqFbzUl8=";
    };
    x86_64-linux = {
      asset = "hunkdiff-linux-x64";
      hash = "sha256-mwtJyWtsbqejH7kMExEyORPLgcAfeA8Ub9oezrFCp9A=";
    };
  };

  source = sources.${stdenv.hostPlatform.system}
    or (throw "hunk: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "hunk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/modem-dev/hunk/releases/download/v${version}/${source.asset}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = source.asset;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 hunk $out/bin/hunk
    runHook postInstall
  '';

  meta = {
    description = "Review-first terminal diff viewer for agentic coders";
    homepage = "https://github.com/modem-dev/hunk";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = builtins.attrNames sources;
  };
}
