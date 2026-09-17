{
  description = "Lean 4 toolchains as Nix packages, plus a home-manager `programs.elan` module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  # The semantic-highlighting fork, which ships its own toolchain package
  # (nix/package.nix) as packages.<system>.default.
  inputs.lean-kiiya.url = "github:Kiiyya/lean4/releases/v4.30.0";
  inputs.lean-kiiya-4_34_0.url = "github:Kiiyya/lean4/releases/v4.34.0";

  outputs =
    {
      self,
      nixpkgs,
      lean-kiiya,
      lean-kiiya-4_34_0,
    }:
    let
      inherit (nixpkgs) lib;
      # x86_64-darwin dropped: nixpkgs-unstable no longer supports it, and the
      # fork ships no toolchain for it.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = lib.genAttrs systems;
    in
    {
      overlays.default =
        final: _prev:
        let
          mkToolchain = final.callPackage ./lib/mkToolchain.nix { };
          inherit (final.stdenv.hostPlatform) system;
        in
        {
          # Keyed by elan toolchain name (= each package's passthru.elanName), so
          # the flake attr, the `elan` name and `lean-toolchain` files all match.
          leanToolchains = {
            # Official release: repackage the release tarball.
            "lean-4.30.0" = mkToolchain {
              version = "4.30.0";
              hashes = {
                x86_64-linux = "sha256-Ta10FBwsEZyhqmJmVr6DuOFCOK+6lycf178es/CBsxk=";
                aarch64-linux = "sha256-yZxvDt1EaVbUdYxZ1Dg+jmQR/2zHGgH5yqvl66RUEh0=";
                aarch64-darwin = "sha256-By3KSjj7wNPO25b+qIbMJDtCTyvRYkdZYgC5qauT8PU=";
              };
            };

            # A fork that builds its own toolchain package.
            "lean-4.30.0-kiiya" = lean-kiiya.packages.${system}.default;
            "lean-4.34.0-kiiya" = lean-kiiya-4_34_0.packages.${system}.default;
          };
        };

      # For adding an official release without touching this repo.
      lib.mkToolchain = pkgs: pkgs.callPackage ./lib/mkToolchain.nix { };

      # `leanToolchains` is already exactly the set of toolchain packages.
      packages = eachSystem (
        system: (nixpkgs.legacyPackages.${system}.extend self.overlays.default).leanToolchains
      );

      homeManagerModules = rec {
        elan = import ./modules/elan.nix;
        default = elan;
      };

      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
