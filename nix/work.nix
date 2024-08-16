# work-machine specific stuff - like env vars needed for netskope
{ pkgs, ... }:
{
  environment.variables = let
    # this is all public keys, but IT doesn't want us throwing the bundle in
    # public repos so this is just the path my work machines would both expect
    # to find it.
    path = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
  in {
    NIX_SSL_CERT_FILE = path;
    CURL_CA_BUNDLE = path;
    GIT_SSL_CAPATH = path;
    GIT_SSL_CAINFO = path;
    SSL_CERT_FILE = path;
    NODE_EXTRA_CA_CERTS = path;
  };

  nixpkgs.overlays = [
    (self: super: {
      zig = super.zig.overrideAttrs (old: {
        patches = [ ../home-manager/zig_cert.patch ];
      });
    })
  ];

  services.tailscale = {
    enable = true;
    package = pkgs.stdenv.mkDerivation {
      pname = "tailscale-cp";
      version = pkgs.tailscale.version;
      src = pkgs.tailscale;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src/bin/tailscaled $out/bin/docker
        ln -s $out/bin/docker $out/bin/tailscaled
        ln -s $out/bin/docker $out/bin/tailscale
      '';
    };
  };
}
