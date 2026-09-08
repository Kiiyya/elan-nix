{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  zstd,
  gmp,
  libuv,
  zlib,
  libxml2,
  ncurses,
}:

# Repackage an official Lean release tarball as an elan toolchain. Forks that
# ship their own toolchain package (a flake `packages.<system>.default`) are
# used directly and don't go through here.
{
  version,
  hashes,
  elanName ? "lean-${version}",
}:

let
  releaseSuffix = {
    x86_64-linux = "linux";
    aarch64-linux = "linux_aarch64";
    x86_64-darwin = "darwin";
    aarch64-darwin = "darwin_aarch64";
  };
  inherit (stdenv.hostPlatform) system isLinux;
in

assert lib.assertMsg (releaseSuffix ? ${system}) "mkToolchain: no Lean release for ${system}";

stdenvNoCC.mkDerivation {
  pname = "lean4-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/leanprover/lean4/releases/download/v${version}/lean-${version}-${releaseSuffix.${system}}.tar.zst";
    hash = hashes.${system};
  };

  nativeBuildInputs = [ zstd ] ++ lib.optional isLinux autoPatchelfHook;

  buildInputs = lib.optionals isLinux [
    (lib.getLib stdenv.cc.cc)
    gmp
    libuv
    zlib
    libxml2
    ncurses
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r . "$out"
    runHook postInstall
  '';

  passthru.elanName = elanName;

  meta = {
    description = "Lean 4 toolchain ${version} (official release binaries)";
    homepage = "https://github.com/leanprover/lean4";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.unix;
    mainProgram = "lean";
  };
}
