# work-machine specific stuff - like env vars needed for netskope
{ ... }: {
  programs.zsh.variables = {
    NIX_SSL_CERT_FILE = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
    CURL_CA_BUNDLE = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
    GIT_SSL_CAPATH = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
    GIT_SSL_CAINFO = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
    SSL_CERT_FILE = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
    NODE_EXTRA_CA_CERTS = "/Library/Application\ Support/Netskope/STAgent/data/netskope-cert-bundle.pem";
  };
}
