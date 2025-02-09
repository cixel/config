# work-machine specific stuff - like env vars needed for netskope
{ pkgs, ... }:
{
  environment.variables =
    let
      # this is all public keys, but IT doesn't want us throwing the bundle in
      # public repos so this is just the path my work machines would both expect
      # to find it.
      path = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
    in
    {
      NIX_SSL_CERT_FILE = path;
      CURL_CA_BUNDLE = path;
      GIT_SSL_CAPATH = path;
      GIT_SSL_CAINFO = path;
      SSL_CERT_FILE = path;
      NODE_EXTRA_CA_CERTS = path;
    };

  services.tailscale = {
    enable = true;
    package = pkgs.stdenv.mkDerivation {
      pname = "tailscale-cp";
      version = pkgs.tailscale.version;
      src = pkgs.tailscale;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/bin
        cp $src/bin/tailscaled $out/bin/gvproxy
        ln -s $out/bin/gvproxy $out/bin/tailscaled
        ln -s $out/bin/gvproxy $out/bin/tailscale
      '';
    };
  };

  nix.settings.http2 = false;

  # https://github.com/LnL7/nix-darwin/blob/master/modules/services/tailscale.nix#L66C2-L72C7
  environment.etc."resolver/c.headscale.ehden.net".text = "nameserver 100.100.100.100";
  environment.etc."resolver/c.headscale.ehden.net".knownSha256Hashes = [
    "2c28f4fe3b4a958cd86b120e7eb799eee6976daa35b228c885f0630c55ef626c"
  ];
}
