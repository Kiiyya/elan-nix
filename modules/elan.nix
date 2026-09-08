{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.elan;

  toolchains =
    if lib.isList cfg.toolchains then
      lib.listToAttrs (
        map (
          drv:
          lib.nameValuePair (drv.elanName or (throw ''
            programs.elan.toolchains: the package '${drv.pname or drv.name}' has no
            `passthru.elanName`. Give it one, or use the attribute-set form to name it:
            programs.elan.toolchains = { "lean-x.y.z" = thePackage; };
          '')
          ) drv
        ) cfg.toolchains
      )
    else
      cfg.toolchains;

  hasDefault = cfg.defaultToolchain != null;

  settingsToml = (pkgs.formats.toml { }).generate "settings.toml" {
    default_toolchain = cfg.defaultToolchain;
    version = "1";
  };

  toolchainDir = pkgs.linkFarm "elan-toolchains" toolchains;
in
{
  options.programs.elan = {
    enable = lib.mkEnableOption "elan, the Lean toolchain manager";

    package = lib.mkPackageOption pkgs "elan" { };

    toolchains = lib.mkOption {
      type = with lib.types; either (listOf package) (attrsOf package);
      default = [ ];
      example = lib.literalExpression "[ elan-nix.packages.\${system}.\"lean-4.30.0\" ]";
      description = ''
        Lean toolchains to make available to elan. Each is a plain package laid
        out as an elan toolchain — `bin/{lean,lake,leanc,clang}`, `lib/lean/…` —
        whether it comes from {var}`elan-nix.leanToolchains`, another flake that
        builds Lean into a package, or your own derivation.

        A list registers each under its `passthru.elanName`; an attribute set
        registers each under its attribute name (use this for packages without
        an `elanName`). elan rejects names containing `_`; use `-` or `.`.
      '';
    };

    defaultToolchain = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "lean-4.30.0";
      description = ''
        Toolchain to record as elan's global default. Must name one of
        {option}`programs.elan.toolchains`.
      '';
    };

    declarative = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether Nix should own `~/.elan` entirely. When false (the default),
        the configured toolchains are linked in but elan may still install and
        update other toolchains itself.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ cfg.package ];

        assertions = [
          {
            assertion = !hasDefault || toolchains ? ${cfg.defaultToolchain};
            message = "programs.elan.defaultToolchain '${toString cfg.defaultToolchain}' is not one of programs.elan.toolchains.";
          }
          {
            assertion = lib.all (n: builtins.match "[A-Za-z0-9][A-Za-z0-9.-]*" n != null) (
              builtins.attrNames toolchains
            );
            message = "programs.elan.toolchains: elan rejects names with '_' (and other punctuation); use '-' or '.'. Got: ${lib.concatStringsSep ", " (builtins.attrNames toolchains)}";
          }
        ];
      }

      (lib.mkIf cfg.declarative {
        home.file.".elan/toolchains" = {
          source = toolchainDir;
          force = true;
        };
        home.file.".elan/settings.toml" = lib.mkIf hasDefault {
          source = settingsToml;
          force = true;
        };
      })

      (lib.mkIf (!cfg.declarative) {
        home.file = lib.mapAttrs' (
          name: drv:
          lib.nameValuePair ".elan/toolchains/${name}" {
            source = drv;
            force = true;
          }
        ) toolchains;

        home.activation.elanDefault = lib.mkIf hasDefault (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run ${lib.getExe cfg.package} default ${lib.escapeShellArg cfg.defaultToolchain}
          ''
        );
      })
    ]
  );
}
