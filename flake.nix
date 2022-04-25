{
  description = "fbrs.io";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in
      rec {
        devShell = pkgs.mkShell
          {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              shellcheck
              lua
              pandoc
              shfmt
              zola
              nodePackages.prettier
            ];
          };
      }
    );
}
