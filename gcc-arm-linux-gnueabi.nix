{ stdenv, fetchurl, lib, ncurses5, python27, expat }:

# ripped off from gcc-arm-embedded
stdenv.mkDerivation rec {
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
}
