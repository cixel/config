# work-machine specific stuff - like env vars needed for netskope
{ user }: { pkgs, ... }:
{
  nixpkgs.overlays = [
    (self: super: {
      zig = super.zig.overrideAttrs (old: {
        # src = pkgs.fetchFromGitHub {
        #   owner = "ziglang";
        #   repo = "zig";
        #   rev = "11176d22f82861b4b6967b77f753414f214bc632";
        #   hash = "sha256-pZIUvhcEqkIi+xSMBIRcS9GW9V/zvs8Y1/KbLYfSb1c=";
        # };
        patches = (
          if pkgs.stdenv.isDarwin then [ ./home-manager/zig_cert.patch ]
          else [ ]
        );
      });

      tailscale = super.tailscale.overrideAttrs (old: {
        # undo the wrapping done by:
        # https://github.com/NixOS/nixpkgs/commit/4b2abf40c55821bada2664aff7474a77812a9bce
        # I don't need it and it messes up some stuff.
        #
        # another potential way to do this is to rename .tailscaled-wrapped and
        # edit the wrapper script
        postInstall = old.postInstall + ''
          cp $out/bin/.tailscaled-wrapped $out/bin/tailscaled
          rm $out/bin/tailscale
          ln -s $out/bin/tailscaled $out/bin/tailscale
        '';
      });
    })
  ];

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

  home-manager.users.${user} = {
    home.packages = [ (pkgs.python3Packages.callPackage ./home-manager/detect-secrets.nix { }) ];

    programs.git = {
      userEmail = "ehden@contrastsecurity.com";

      extraConfig.url."git@github.com:Contrast-Security-Inc/".insteadOf = "https://github.com/Contrast-Security-Inc/";
      extraConfig.url."git@bitbucket.org:".insteadOf = "https://bitbucket.org/";
    };

    programs.jujutsu.settings = {
      user = {
        name = "Ehden Sinai";
        email = "ehden@contrastsecurity.com";
      };
    };
  };
}
