let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    nixpkgs-fmt
    shellcheck
    shfmt
    zola
    nodePackages.prettier
  ];
}
