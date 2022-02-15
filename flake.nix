{
  description = "seL4 development shells";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-21.11;
    mach-nix.url = github:DavHau/mach-nix;
    flake-utils.url = github:numtide/flake-utils;
    nixpkgs-master.url = github:nixos/nixpkgs/master;
    nixpkgs-1000teslas.url = github:1000teslas/nixpkgs/isabelle;
    rust-overlay.url = github:oxalica/rust-overlay;
    nixpkgs-1809 = { url = github:nixos/nixpkgs/nixos-18.09; flake = false; };
  };

  outputs =
    { self
    , nixpkgs
    , mach-nix
    , flake-utils
    , nixpkgs-master
    , nixpkgs-1000teslas
    , rust-overlay
    , nixpkgs-1809
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      pkgs = import nixpkgs {
        inherit system; overlays = [ (import rust-overlay) ];
      };
      pkgs-master = import nixpkgs-master {
        inherit system;
      };
      pkgs-1000teslas = import nixpkgs-1000teslas {
        inherit system;
      };
      sel4-gcc-version = "gcc10";
    in
    rec {
      packages =
        let
          mk-compiler = { nix-target-name, sel4-target-name ? nix-target-name, enableMultilib ? false, ccOverrideAttrs ? (_: { }) }:
            with import nixpkgs { inherit system; crossSystem = { config = nix-target-name; }; };
            let
              sel4-gcc = buildPackages.wrapCC ((buildPackages.${sel4-gcc-version}.cc.override { inherit enableMultilib; }).overrideAttrs ccOverrideAttrs);
              sel4-gcc-stdenv = overrideCC gccStdenv sel4-gcc;
            in
            runCommand "${sel4-gcc-version}-${sel4-target-name}" { } ''
              mkdir -p $out/bin
              cd ${sel4-gcc-stdenv.cc.cc}/bin
              for f in *; do
                ln -s $(realpath $f) $out/bin/''${f/${nix-target-name}/${sel4-target-name}}
              done
              cd ${sel4-gcc-stdenv.cc.bintools.bintools}/bin
              for f in *; do
                ln -s $(realpath $f) $out/bin/''${f/${nix-target-name}/${sel4-target-name}}
              done
            '';
        in
        {
          inherit (pkgs-1000teslas) isabelle;
          gcc-arm-linux-gnueabi = mk-compiler { nix-target-name = "armv7a-unknown-linux-gnueabi"; sel4-target-name = "arm-linux-gnueabi"; };
          gcc-aarch64-linux-gnu = mk-compiler { nix-target-name = "aarch64-unknown-linux-gnu"; sel4-target-name = "aarch64-linux-gnu"; };
          gcc-arm-none-eabi = mk-compiler { nix-target-name = "aarch64-none-elf"; };
          gcc-riscv64-unknown-elf = mk-compiler {
            nix-target-name = "riscv64-none-elf";
            sel4-target-name = "riscv64-unknown-elf";
            enableMultilib = true;
            ccOverrideAttrs = _: {
              prePatch = ''
                cp ${./riscv-t-elf-multilib} gcc/config/riscv/t-elf-multilib
              '';
            };
          };
        };
      devShells = with pkgs;
        let
          mn = import mach-nix { inherit pkgs; python = "python39"; };
          mk-sel4-deps = { python, qemu ? pkgs.qemu }: [ python qemu ] ++ [
            bashInteractive
            ccache
            cmake
            ninja
            libxml2
            protobuf3_12
            dtc
            packages.gcc-arm-linux-gnueabi
            astyle
            packages.gcc-aarch64-linux-gnu
            ubootTools
            cpio
            packages.gcc-riscv64-unknown-elf
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
            fakeroot
          ] ++
          # not necessary for building, only for debugging
          [
            minicom
          ];
          l4v-deps = camkes-deps ++ [
            mlton
            packages.isabelle
            texlive.combined.scheme-full
          ];
          cp-deps =
            let rust = rust-bin.stable.latest.default.override {
              targets = [ "x86_64-unknown-linux-musl" ];
            }; in
            mk-sel4-deps
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
                qemu = (qemu.overrideAttrs (old: {
                  src = fetchgit {
                    url = "https://github.com/Xilinx/qemu.git";
                    rev = "e353d497d8aff64b42575fa4799a2f43555e0502";
                    sha256 = "sha256-2IiLw/RAjckRbu+Reb1L/saPYNuy8kl7TADLTPi06MA=";
                    fetchSubmodules = true;
                  };
                  patches = [ ];
                  buildInputs = old.buildInputs ++ [ libgcrypt ];
                  configureFlags = [
                    "--enable-fdt"
                    "--disable-kvm"
                    "--enable-gcrypt"
                  ];
                })).override
                  { hostCpuTargets = [ "aarch64-softmmu" "microblazeel-softmmu" ]; };
              } ++ [
              pandoc
              texlive.combined.scheme-full
              packages.gcc-arm-none-eabi
              rust
            ];
          multilibMkShell = mkShell.override { stdenv = overrideCC gccStdenv (wrapCCMulti pkgs.${sel4-gcc-version}); };
        in
        {
          sel4 = multilibMkShell { buildInputs = sel4-deps; };
          camkes = multilibMkShell {
            buildInputs = camkes-deps;
            NIX_PATH = "nixpkgs=${nixpkgs-1809}";
          };
          l4v = multilibMkShell { buildInputs = l4v-deps; };
          cp = multilibMkShell { buildInputs = cp-deps; PYOXIDIZER_SYSTEM_RUST = 1; };
        };
    });
}
