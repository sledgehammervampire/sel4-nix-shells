{
  description = "sel4 development shells";

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
        # package description ripped off from gcc-arm-embedded
        gcc-arm-linux-gnueabi = pkgs.callPackage
          ({ stdenv, fetchurl, lib, ncurses5, python27, expat }: stdenv.mkDerivation rec {
            pname = "gcc-arm-linux-gnueabi";
            version = "8.2";
            release = "2019.01";
            src = fetchurl
              {
                url = "https://developer.arm.com/-/media/Files/downloads/gnu-a/${version}-${release}/gcc-arm-${version}-${release}-x86_64-arm-linux-gnueabi.tar.xz";
                sha256 = "sha256-OWUVAzGMMKqVXmO/gCxP7pzOWFdW0rPizdSkRX1AxFg=";
              };
            dontConfigure = true;
            dontBuild = true;
            dontPatchELF = true;
            dontStrip = true;
            installPhase = ''
              mkdir -p $out
              cp -r * $out
              ln -s $out/share/man $out/man
            '';
            preFixup = ''
              find $out -type f | while read f; do
                patchelf "$f" > /dev/null 2>&1 || continue
                patchelf --set-interpreter $(cat ${stdenv.cc}/nix-support/dynamic-linker) "$f" || true
                patchelf --set-rpath ${lib.makeLibraryPath [ "$out" stdenv.cc.cc ncurses5 python27 expat ]} "$f" || true
              done
            '';
            meta = { platforms = [ "x86_64-linux" ]; };
          })
          { };
      };
      devShell =
        with pkgs;
        mkShell
          {
            buildInputs =
              let
                myPython = (import mach-nix { inherit pkgs; python = "python39"; }).mkPython {
                  requirements = ''
                    sel4-deps
                    setuptools
                    protobuf==3.12.4
                  '';
                };
              in
              [
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
              ];
          };
    });
}
