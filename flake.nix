{
  description = "seL4 development shells";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-22.05;
    mach-nix.url = github:DavHau/mach-nix;
    flake-utils.url = github:numtide/flake-utils;
    nixpkgs-master.url = github:nixos/nixpkgs/master;
    nixpkgs-1000teslas.url = github:1000teslas/nixpkgs/isabelle;
    rust-overlay.url = github:oxalica/rust-overlay;
    nixpkgs-2205.url = github:nixos/nixpkgs/nixos-22.05;
    nixpkgs-2111.url = github:nixos/nixpkgs/nixos-21.11;
  };

  outputs =
    { self
    , nixpkgs
    , mach-nix
    , flake-utils
    , nixpkgs-master
    , nixpkgs-1000teslas
    , rust-overlay
    , nixpkgs-2111
    , nixpkgs-2205
    }:
    flake-utils.lib.eachDefaultSystem (system:
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
      pkgs-2111 = nixpkgs-2111.legacyPackages.${system};
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
          xilinx-qemu = with pkgs-2111; (qemu.overrideAttrs (old: {
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
          rust-nightly = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
            extensions = [ "rust-src" ];
            targets = [ "aarch64-unknown-none" ];
          });
        };
      devShells = with pkgs;
        let
          mn = import mach-nix {
            inherit pkgs; python = "python39";
            pypiDataRev = "317719c305a4b1bd97cfec9366d118228fefa690";
            pypiDataSha256 = "sha256:0a9qi9wqj5jw09f3widpd6rpzvwrhvw4cw8mqd063yp009l91siv";
          };
          mk-sel4-deps = inputs@{ python, ... }:
            lib.attrValues
              ({
                inherit (pkgs) qemu cmake ccache ninja libxml2 dtc astyle ubootTools cpio protobuf;
                inherit (packages) gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu gcc-riscv64-unknown-elf;
                bash = bashInteractive;
              } // inputs);
          sel4-deps = mk-sel4-deps {
            python = mn.mkPython {
              requirements = ''
                setuptools==61.2.0
                protobuf==3.12.4
                sel4-deps==0.3.1
                nose==1.3.7
              '';
              providers.unittest2 = "nixpkgs";
              providers.libarchive-c = "nixpkgs";
            };
            protobuf = pkgs-2111.protobuf3_12;
          };
          camkes-deps = mk-sel4-deps
            {
              python = mn.mkPython {
                requirements = ''
                  setuptools==61.2.0
                  protobuf==3.12.4
                  camkes-deps==0.7.3
                  nose==1.3.7
                '';
                providers.unittest2 = "nixpkgs";
                providers.libarchive-c = "nixpkgs";
              };
            } ++ [
            stack
            fakeroot
            gmp.out
          ];
          l4v-deps = sel4-deps ++ [
            mlton
            texlive.combined.scheme-full
          ];
          cp-deps =
            let
              rust = rust-bin.stable.latest.default.override {
                targets = [ "x86_64-unknown-linux-musl" ];
              };
              tex = texlive.combine {
                inherit (texlive) scheme-medium titlesec;
              };
            in
            mk-sel4-deps
              {
                python = mn.mkPython {
                  requirements = ''
                    setuptools==61.2.0
                    pyoxidizer==0.17.0
                    mypy==0.910
                    black==21.7b0
                    flake8==3.9.2
                    ply==3.11
                    Jinja2==3.0.3
                    PyYAML==6.0
                    pyfdt==0.3
                    jsonschema==4.4.0
                    sel4-deps==0.3.1
                  '';
                  packagesExtra = [
                    (
                      let
                        src = builtins.fetchGit {
                          url = "https://github.com/1000teslas/capdl/";
                          ref = "package";
                          rev = "8f6468ffd1b7a4b0f198b4db1ec137aef5788ba3";
                        };
                      in
                      mn.buildPythonPackage {
                        inherit src;
                        pname = "capdl";
                        version = "0.2.1-dev";
                        sourceRoot = "source/python-capdl-tool";
                        requirements = builtins.readFile "${src}/python-capdl-tool/requirements.txt";
                      }
                    )
                  ];
                  providers.libarchive-c = "nixpkgs";
                };
                qemu = packages.xilinx-qemu;
              } ++ [
              pandoc
              tex
              packages.gcc-arm-none-eabi
              rust
              stack
              gmp.out
              gdb
            ];
          aos-deps =
            mk-sel4-deps
              {
                python = mn.mkPython {
                  requirements = ''
                    setuptools==61.2.0
                    protobuf==3.12.4
                    sel4-deps==0.3.1
                    nose==1.3.7
                    tempita==0.5.2
                  '';
                  providers.libarchive-c = "nixpkgs";
                };
                gcc-arm-linux-gnueabi = null;
                gcc-riscv64-unknown-elf = null;
              } ++ [
              packages.rust-nightly
              corrosion
              cargo-edit
              websocat
              curl
              llvmPackages_latest.libclang.lib
            ];
          multilibMkShell = mkShell.override { stdenv = overrideCC gccStdenv (wrapCCMulti pkgs.${sel4-gcc-version}); };
        in
        {
          sel4 = multilibMkShell { buildInputs = sel4-deps; };
          camkes = multilibMkShell {
            buildInputs = camkes-deps;
            # for stack
            NIX_PATH = "nixpkgs=${nixpkgs-2205}";
          };
          l4v = multilibMkShell { buildInputs = l4v-deps; };
          cp = multilibMkShell {
            buildInputs = cp-deps;
            PYOXIDIZER_SYSTEM_RUST = 1;
            # for stack
            NIX_PATH = "nixpkgs=${nixpkgs-2205}";
          };
          aos = mkShell {
            buildInputs = aos-deps;
            LIBCLANG_PATH = "${llvmPackages_latest.libclang.lib}/lib";
          };
        };
    });
}
