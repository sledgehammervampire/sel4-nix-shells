{ stdenv, fetchurl, lib, ncurses5, python27, expat }:

# ripped off from gcc-arm-embedded
stdenv.mkDerivation rec {
  pname = "gcc-arm-none-eabi";
  version = "10.2";
  release = "2020.11";
  src = fetchurl
    {
      url = "https://developer.arm.com/-/media/Files/downloads/gnu-a/${version}-${release}/binrel/gcc-arm-${version}-${release}-x86_64-aarch64-none-elf.tar.xz";
      sha256 = "sha256-Mqv7x7JMVlQvKm5pada4eH5H9yI+jyCX2EFR69n4Z0M=";
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
}
