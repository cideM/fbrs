{
  description = "fbrs.io";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        generateResume = pkgs.writeShellApplication {
          name = "generate-fbrs-resume";
          runtimeInputs = [pkgs.pandoc];
          text = ''
            awk '/+++/ { COUNT += 1; next }; COUNT >= 2 { print $0 }' ./content/resume.md \
            | pandoc --standalone --embed-resources --standalone --from markdown --to html -o resume.html --metadata title="Florian Beeres" -c ./resume/style.css
          '';
        };
      in {
        packages = rec {
          inherit generateResume;
        };
        apps = rec {
          generate-resume = flake-utils.lib.mkApp {
            drv =
              self.packages.${system}.generateResume;
          };
        };
        devShell =
          pkgs.mkShell
          {
            buildInputs = with pkgs; [
              alejandra
              zola
              imagemagick
              nodePackages.prettier
              nodejs-slim
            ];
          };
      }
    );
}
