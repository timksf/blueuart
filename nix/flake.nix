# SPDX-License-Identifier: MIT

{
    description = "";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/25.11";
        flake-utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, flake-utils, nixpkgs } :
        flake-utils.lib.eachSystem ["x86_64-linux"] (system: let
            pkgs = import nixpkgs {
                inherit system;
            };
            python = pkgs.python313.withPackages (ps:
                with ps; [
                    pyserial
                ]);
            in { 
                devShell = with pkgs; pkgs.mkShellNoCC {
                    packages = [python] ++ (with pkgs; [
                        bluespec
                        yosys
                        iverilog
                    ]);
                };
            }
        );
}