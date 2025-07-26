nixpkgs:
let
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
in
f:
nixpkgs.lib.genAttrs supportedSystems (
  system:
  f {
    pkgs = import nixpkgs { inherit system; };
  }
)
