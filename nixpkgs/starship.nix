{ stdenv, fetchFromGitHub, rustPlatform, pkg-config, openssl, installShellFiles
, libiconv, darwin, Security }:
# , libiconv, darwin }:

rustPlatform.buildRustPackage rec {
  pname = "starship";
  version = "0.44.0-fmt";

  src = fetchFromGitHub {
    owner = "starship";
    repo = pname;
    rev = "a89f41f8e8e3691d6499357509ff5f293dcf8007";
    # sha256 = "1pxrg5sfqqkvqww3fabq64j1fg03v5fj5yvm2xg2qa5n2f2qwnhi";
    sha256 = "0fqbbax783bp066wqhb3qmiw262da25kjb2ypsfcq3k8bxxw8qlr";
  };

  nativeBuildInputs = [ installShellFiles ] ++ stdenv.lib.optionals stdenv.isLinux [ pkg-config ];

  buildInputs = stdenv.lib.optionals stdenv.isLinux [ openssl ]
    ++ stdenv.lib.optionals stdenv.isDarwin [ libiconv Security ];
    # ++ stdenv.lib.optionals stdenv.isDarwin [ libiconv darwin.apple_sdk.frameworks.Security ];

  postPatch = ''
    substituteInPlace src/utils.rs \
      --replace "/bin/echo" "echo"
  '';

  postInstall = ''
    for shell in bash fish zsh; do
      $out/bin/starship completions $shell > starship.$shell
      installShellCompletion starship.$shell
    done
  '';

  # cargoSha256 = "1b5gsw7jpiqjc7kbwf2kp6h6ks7jcgygrwzvn2akz86z40sskyg3";
  cargoSha256 = "1dflcic5176qldi3hq9vawfsp52jazagmfb731qxqlmj2f4injb9";

  preCheck = ''
    substituteInPlace tests/testsuite/common.rs \
      --replace "./target/debug/starship" "./$releaseDir/starship"
    substituteInPlace tests/testsuite/python.rs \
      --replace "#[test]" "#[test] #[ignore]"
  '';

  checkFlagsArray = [ "--skip=directory::home_directory" "--skip=directory::directory_in_root" ];

  meta = with stdenv.lib; {
    description = "A minimal, blazing fast, and extremely customizable prompt for any shell";
    homepage = "https://starship.rs";
    license = licenses.isc;
    maintainers = with maintainers; [ bbigras davidtwco filalex77 Frostman marsam ];
    platforms = platforms.all;
  };
}
