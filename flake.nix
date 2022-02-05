{
  description = "seL4 development shells";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-21.11;
    mach-nix.url = github:DavHau/mach-nix;
    flake-utils.url = github:numtide/flake-utils;
    nixpkgs-master.url = github:nixos/nixpkgs/master;
    nixpkgs-1000teslas.url = github:1000teslas/nixpkgs/isabelle;
  };

  outputs =
    { self
    , nixpkgs
    , mach-nix
    , flake-utils
    , nixpkgs-master
    , nixpkgs-1000teslas
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };
      pkgs-master = import nixpkgs-master {
        inherit system;
      };
      pkgs-1000teslas = import nixpkgs-1000teslas {
        inherit system;
      };
    in
    rec {
      packages = {
        inherit (pkgs-1000teslas) isabelle;
        gcc-arm-linux-gnueabi = pkgs.callPackage ./gcc-arm-linux-gnueabi.nix { };
        gcc-aarch64-linux-gnu = pkgs.callPackage ./gcc-aarch64-linux-gnu.nix { };
        gcc-arm-none-eabi = pkgs.callPackage ./gcc-arm-none-eabi.nix { };
      };
      devShells = with pkgs;
        let
          mn = import mach-nix { inherit pkgs; python = "python39"; };
          mk-sel4-deps = { python }: [
            python
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
            packages.gcc-aarch64-linux-gnu
          ];
          sel4-deps = mk-sel4-deps {
            python = mn.mkPython {
              requirements = ''
                setuptools
                protobuf==3.12.4
                sel4-deps
                nose
              '';
              providers.unittest2 = "nixpkgs";
              providers.libarchive-c = "nixpkgs";
            };
          };
          camkes-deps = mk-sel4-deps
            {
              python = mn.mkPython {
                requirements = ''
                  setuptools
                  protobuf==3.12.4
                  camkes-deps
                  nose
                '';
                providers.unittest2 = "nixpkgs";
                providers.libarchive-c = "nixpkgs";
              };
            } ++ [
            stack
          ];
          l4v-deps = camkes-deps ++ [
            mlton
            packages.isabelle
            texlive.combined.scheme-full
          ];
          cp-deps = mk-sel4-deps
            {
              python = mn.mkPython {
                requirements = ''
                  setuptools
                  pyoxidizer==0.17.0
                  mypy==0.910
                  black==21.7b0
                  flake8==3.9.2
                  ply==3.11
                  Jinja2==3.0.3
                  PyYAML==6.0
                  pyfdt==0.3
                '';
              };
            } ++ [ pandoc texlive.combined.scheme-full packages.gcc-arm-none-eabi ];
        in
        {
          sel4 = mkShell { buildInputs = sel4-deps; };
          camkes = mkShell { buildInputs = camkes-deps; };
          l4v = mkShell { buildInputs = l4v-deps; };
          cp = mkShell { buildInputs = cp-deps; };
        };
      devShell = devShells.camkes;
    });
}
