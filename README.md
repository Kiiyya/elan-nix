# elan-nix

> **Disclaimer:** this repository was mostly written by Claude (Anthropic's
> Claude Code). It works for the author's use case but has not been broadly
> tested — read the code before relying on it.

Installs `elan`, keeps a curated list of Lean 4 toolchains, and links them into
`~/.elan/toolchains/` via a home-manager module.

**A toolchain is just a Nix package** laid out how elan expects —
`bin/{lean,lake,leanc,clang}`, `lib/lean/…`, `passthru.elanName`. elan-nix does
not build Lean from source: a toolchain is an official release tarball,
repackaged, or a package a Lean repo builds of itself.

## Setup

```nix
inputs.elan-nix.url = "github:Kiiyya/elan-nix";

# NixOS: expose pkgs.leanToolchains (the curated set)
nixpkgs.overlays = [ inputs.elan-nix.overlays.default ];

# home-manager
imports = [ inputs.elan-nix.homeManagerModules.elan ];
programs.elan = {
  enable = true;
  toolchains = [ pkgs.leanToolchains."lean-4.30.0" ];
  # defaultToolchain = "lean-4.30.0";
  # declarative = true;   # let Nix fully own ~/.elan
};
```

`toolchains` is a list of packages (each linked under its `passthru.elanName`),
or `{ "<elan name>" = package; }` for packages without one. elan rejects names
containing `_`; use `-` or `.`.

## The three ways to get a toolchain

### 1. From the curated list

`pkgs.leanToolchains` (or `elan-nix.packages.<system>`) holds the curated
toolchains, keyed by elan name — so the attr, the elan name and `lean-toolchain`
files match:

```nix
toolchains = [ pkgs.leanToolchains."lean-4.30.0-kiiya" ];
```

Adding a fork to the list = a flake input of elan-nix plus one line in
`leanToolchains` ([`flake.nix`](./flake.nix)); the fork must expose
`packages.<system>.default` (see [below](#making-a-lean-repo-ship-a-toolchain-package)).

### 2. Bring your own

A version that isn't in the list but lives in a repo that ships a toolchain
package — add it to your own flake, no elan-nix change:

```nix
inputs.my-lean.url = "github:you/lean4?ref=my-branch";

programs.elan.toolchains = [ inputs.my-lean.packages.${pkgs.system}.default ];
# no passthru.elanName? name it:
programs.elan.toolchains = { "lean-my-branch" = inputs.my-lean.packages.${pkgs.system}.default; };
```

### 3. Repackage a release tarball

The escape hatch, for a version with no toolchain-package flake anywhere.
`lib.mkToolchain` fetches the official release `.tar.zst` and `autoPatchelf`s it:

```nix
inputs.elan-nix.lib.mkToolchain pkgs {
  version = "4.29.0";
  hashes = {
    x86_64-linux = "sha256-…";
    aarch64-linux = "sha256-…";
    aarch64-darwin = "sha256-…";
  };
};
```

`pkgs.leanToolchains."lean-4.30.0"` is exactly this. Building an arbitrary source
tree from inside elan-nix is not supported — give the repo a flake, use way 1/2.

## Making a Lean repo ship a toolchain package

`packages.<system>.default` must be a real derivation (the stock Lean flake only
has a devShell). Port nixpkgs' `pkgs/by-name/le/lean4/package.nix` with
`src = self`, symlink `clang` into `$out/bin/` (Lake resolves its C compiler as
`<sysroot>/bin/clang`, and `elan run` doesn't put the toolchain `bin/` on
`PATH`), and set `passthru.elanName`. `Kiiyya/lean4`'s `nix/package.nix` is a
worked example.

## Outputs

| output | what |
| --- | --- |
| `overlays.default` | adds `pkgs.leanToolchains` — the curated set |
| `packages.<system>.{"lean-4.30.0","lean-4.30.0-kiiya"}` | same set |
| `lib.mkToolchain pkgs { version; hashes; elanName ? }` | repackage a release tarball |
| `homeManagerModules.elan` | the `programs.elan` module |

## Caveats

- `mkToolchain`'s `buildInputs` cover the ELF binaries of the releases it's used
  for; a release that adds a library dependency fails `autoPatchelf` until the
  list is extended.
- The module is home-manager only (elan is per-user).
