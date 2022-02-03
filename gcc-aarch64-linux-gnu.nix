{ stdenv, fetchurl, lib, ncurses5, python27, expat }:

# ripped off from gcc-arm-embedded
stdenv.mkDerivation rec {
  pname = "gcc-aarch64-linux-gnu";
  version = "10.3";
  release = "2021.07";
  src = fetchurl
    {
      url = "https://developer.arm.com/-/media/Files/downloads/gnu-a/${version}-${release}/binrel/gcc-arm-${version}-${release}-x86_64-aarch64-none-linux-gnu.tar.xz";
      sha256 = "sha256-HjPVPepZyN6CO73+B5goC9zROGNscGDanXepfe0JWoQ=";
    };
  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;
  dontStrip = true;
  installPhase = ''
    mkdir -p $out
    cp -r * $out
    ln -s $out/share/man $out/man
    for f in $out/bin/*; do
      ln -s $f ''${f/none-/}
    done
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
