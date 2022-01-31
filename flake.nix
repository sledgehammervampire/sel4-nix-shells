{
  description = "seL4 development shells";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-21.11;
    mach-nix.url = github:DavHau/mach-nix;
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs =
    { self
    , nixpkgs
    , mach-nix
    , flake-utils
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    rec {
      packages = {
        inherit (pkgs) isabelle;
        # package description ripped off from gcc-arm-embedded
        gcc-arm-linux-gnueabi = pkgs.callPackage ./gcc-arm-linux-gnueabi.nix { };
      };
      devShells = with pkgs;
        let
          myPython = (import mach-nix { inherit pkgs; python = "python39"; }).mkPython {
            requirements = ''
              setuptools
              protobuf==3.12.4
              camkes-deps
              nose
            '';
            providers.unittest2 = "nixpkgs";
            providers.libarchive-c = "nixpkgs";
          };
          sel4-deps = [
            myPython
            bashInteractive
            gcc
            ccache
            cmake
            ninja
            libxml2
            protobuf3_12
            dtc
            packages.gcc-arm-linux-gnueabi
            qemu
            astyle
          ];
          camkes-deps = sel4-deps ++ [
            stack
          ];
          l4v-deps = camkes-deps ++ [
            mlton
            packages.isabelle
            texlive.combined.scheme-full
          ];
        in
        {
          sel4 = mkShell { buildInputs = sel4-deps; };
          camkes = mkShell { buildInputs = camkes-deps; };
          l4v = mkShell { buildInputs = l4v-deps; };
        };
      devShell = devShells.camkes;
    });
}
