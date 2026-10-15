{ pkgs }:

# The Go toolchain used on the host (programs.go.package) and baked into the
# Pi Gondolin sandbox image, so both stay on one definition.
#
# Default pkgs.go still tracks 1.26.x, so pin go_1_27 explicitly. It ships
# the GO_NO_VENDOR_CHECKS escape hatch (go_no_vendor_checks-1.27.patch)
# upstream. Drop this pin back to pkgs.go once nixpkgs default is >= 1.27.
pkgs.go_1_27
