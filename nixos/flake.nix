{
  description = "Standalone flake for Automatic Ripping Machine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    pydvdid = {
      url = "github:sjwood/pydvdid/v1.1";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      forEachSystem = import ./systems.nix inputs.nixpkgs;
    in
    {
      packages = forEachSystem (
        { pkgs }:
        rec {
          pydvdid = pkgs.callPackage ./pydvdid.nix { src = inputs.pydvdid; };
          automatic-ripping-machine = pkgs.callPackage ./package.nix {
            inherit pydvdid;
            src = ./..;
          };
          default = automatic-ripping-machine;
        }
      );

      nixosModules = rec {
        automatic-ripping-machine = import ./module.nix self;
        default = automatic-ripping-machine;
      };

      devShells = forEachSystem (
        { pkgs }:
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${pkgs.system}.default ];
          };
        }
      );
    };
}
