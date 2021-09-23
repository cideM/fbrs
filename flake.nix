{
  description = "fbrs.io";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/staging-next";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      rec {
        devShell = pkgs.mkShell
          {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              shellcheck
              shfmt
              zola
              nodePackages.prettier
            ];
          };
      }
    );
}
