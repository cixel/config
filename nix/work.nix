# work-machine specific stuff - like env vars needed for netskope
{ user, system, pkgs, ... }:
let
  # this is all public keys, but IT doesn't want us throwing the bundle in
  # public repos so this is just the path my work machines would both expect
  # to find it.
  netskope_bundle = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
in
{
  nixpkgs.overlays = [
    (self: super: {
      go =
        let
          darwin = super.lib.strings.hasSuffix "darwin" system;
        in
        super.go.overrideAttrs (old: {
          # patches = old.patches ++ (if darwin then [ ./home-manager/fd_fsync_darwin.patch ] else [ ]);
          patches = [ ];
          GOROOT_BOOTSTRAP = "${super.go}/share/go";
        });

      # https://github.com/NixOS/nixpkgs/issues/154163#issuecomment-1350599022
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });

      zig = super.zig.overrideAttrs (old: {
        # src = pkgs.fetchFromGitHub {
        #   owner = "ziglang";
        #   repo = "zig";
        #   rev = "11176d22f82861b4b6967b77f753414f214bc632";
        #   hash = "sha256-pZIUvhcEqkIi+xSMBIRcS9GW9V/zvs8Y1/KbLYfSb1c=";
        # };
        # patches = (if super.stdenv.isDarwin then [ ./home-manager/zig_cert.patch ] else [ ]);
      });

      rtk = super.rtk.overrideAttrs (old: rec {
        # Cargo.toml reports 0.34.3 at this commit; versionCheckHook greps
        # `rtk --version` for this string, so it must match what the binary prints.
        version = "0.34.3";
        # Pinned commit: e4b48ee4ff7e92c36d46984bb897c83237eeb5df
        # Eval-time fetch: runs in the evaluator using nix.conf ssl-cert-file,
        # bypassing the builder sandbox entirely. Sidesteps the Netskope MITM
        # cert handling the FOD fetchFromGitHub would otherwise need.
        src = fetchTarball {
          url = "https://github.com/tmchow/rtk/archive/e4b48ee4ff7e92c36d46984bb897c83237eeb5df.tar.gz";
          sha256 = "sha256:0v1sdg668s6n9xb5h0488j47kqllhli6vwh4fh89anlsimhvg1nm";
        };
        cargoDeps = super.rustPlatform.importCargoLock {
          lockFile = "${src}/Cargo.lock";
        };
        # Hook handlers (Claude/Cursor/Gemini/Copilot + `hook check`) only
        # consult the Rust command registry, so commands defined as bundled
        # TOML filters (jj, ssh, jira, ...) silently passed through. Mirror
        # the toml_filter fallback that `rtk rewrite` already does.
        patches = (old.patches or [ ]) ++ [ ./home-manager/rtk_hook_toml_fallback.patch ];
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
        doCheck = false;
      });
    })
  ];

  environment.variables = {
    AWS_CA_BUNDLE = netskope_bundle;
    CURL_CA_BUNDLE = netskope_bundle;
    GIT_SSL_CAINFO = netskope_bundle;
    GIT_SSL_CAPATH = netskope_bundle;
    NIX_SSL_CERT_FILE = netskope_bundle;
    NODE_EXTRA_CA_CERTS = netskope_bundle;
    REQUESTS_CA_BUNDLE = netskope_bundle;
    SSL_CERT_FILE = netskope_bundle;
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

  # https://github.com/LnL7/nix-darwin/blob/master/modules/services/tailscale.nix#L66C2-L72C7
  environment.etc."resolver/c.headscale.ehden.net".text = "nameserver 100.100.100.100";
  environment.etc."resolver/c.headscale.ehden.net".knownSha256Hashes = [
    "2c28f4fe3b4a958cd86b120e7eb799eee6976daa35b228c885f0630c55ef626c"
  ];

  home-manager.users.${user} = {
    home.packages = [ pkgs.github-copilot-cli ];

    programs.neovim = {
      extraPackages = [ pkgs.copilot-language-server ];
      plugins = with pkgs.vimPlugins; [
        {
          plugin = copilot-lua;
          type = "lua";
          config = builtins.readFile ./home-manager/nvim/config/plugins/copilot.lua;
        }
        blink-copilot
      ];
    };

    programs.antigravity-cli = {
      enable = true;
      package = pkgs.gemini-cli-bin;
    };

    programs.claude-code = {
      enable = true;
      package = pkgs.claude-code;
      # @RTK is a claude-specific directive; prepend it to the shared
      # context. Other agents get the shared file as-is.
      context = ''
        @RTK

        ${builtins.readFile ./home-manager/agents/context.md}
      '';
      skills = ./home-manager/agents/skills;
      commandsDir = ./home-manager/agents/commands;
      mcpServers = {
        atlassian = {
          type = "http";
          url = "https://mcp.atlassian.com/v1/mcp";
        };
        gopls-lsp = {
          type = "stdio";
          command = "gopls";
          args = [ "mcp" ];
        };
        rust-analyzer-lsp = {
          type = "stdio";
          command = "rust-analyzer";
          args = [ "mcp" ];
        };
      };
    };

    programs.git.settings = {
      user.email = "ehden@contrastsecurity.com";

      url."git@bitbucket.org:".insteadOf = "https://bitbucket.org/";
      url."https://github.com/Contrast-Security-Inc/".insteadOf = "git@github.com:Contrast-Security-Inc/";
      url."https://github.com/Contrast-Security-OSS/".insteadOf = "git@github.com:Contrast-Security-OSS/";
    };

    programs.gh = {
      gitCredentialHelper = {
        enable = true;
      };

      hosts = {
        "github.com" = {
          git_protocol = "https";
          user = "cixel";
        };
      };
      settings = {
        aliases = { };
      };
    };

    programs.jujutsu.settings = {
      user = {
        name = "Ehden Sinai";
        email = "ehden@contrastsecurity.com";
      };
    };
  };
}
