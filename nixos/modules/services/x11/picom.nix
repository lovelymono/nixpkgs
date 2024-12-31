{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let

  cfg = config.services.picom;
  opt = options.services.picom;

  pairOf =
    x:
    with lib.types;
    addCheck (listOf x) (y: length y == 2) // { description = "pair of ${x.description}"; };

  mkDefaultAttrs = lib.mapAttrs (n: v: lib.mkDefault v);

  # Basically a tinkered lib.generators.mkKeyValueDefault
  # It either serializes a top-level definition "key: { values };"
  # or an expression "key = { values };"
  mkAttrsString =
    top:
    lib.mapAttrsToList (
      k: v:
      let
        sep = if (top && lib.isAttrs v) then ":" else "=";
      in
      "${lib.escape [ sep ] k}${sep}${mkValueString v};"
    );

  # This serializes a Nix expression to the libconfig format.
  mkValueString =
    v:
    if lib.types.bool.check v then
      lib.boolToString v
    else if lib.types.int.check v then
      toString v
    else if lib.types.float.check v then
      toString v
    else if lib.types.str.check v then
      "\"${lib.escape [ "\"" ] v}\""
    else if builtins.isList v then
      "[ ${lib.concatMapStringsSep " , " mkValueString v} ]"
    else if lib.types.attrs.check v then
      "{ ${lib.concatStringsSep " " (mkAttrsString false v)} }"
    else
      throw ''
        invalid expression used in option services.picom.settings:
        ${v}
      '';

  toConf = attrs: lib.concatStringsSep "\n" (mkAttrsString true cfg.settings);

  configFile = pkgs.writeText "picom.conf" (toConf cfg.settings);

in
{

  imports = [
    (lib.mkAliasOptionModuleMD [ "services" "compton" ] [ "services" "picom" ])
    (lib.mkRemovedOptionModule [ "services" "picom" "refreshRate" ] ''
      This option corresponds to `refresh-rate`, which has been unused
      since picom v6 and was subsequently removed by upstream.
      See https://github.com/yshui/picom/commit/bcbc410
    '')
    (lib.mkRemovedOptionModule [ "services" "picom" "experimentalBackends" ] ''
      This option was removed by upstream since picom v10.
    '')
  ];

  options.services.picom = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether or not to enable Picom as the X.org composite manager.
      '';
    };

    package = lib.mkPackageOption pkgs "picom" { };

    fade = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Fade windows in and out.
      '';
    };

    fadeDelta = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      example = 5;
      description = ''
        Time between fade animation step (in ms).
      '';
    };

    fadeSteps = lib.mkOption {
      type = pairOf (lib.types.numbers.between 0.01 1);
      default = [
        0.028
        0.03
      ];
      example = [
        0.04
        0.04
      ];
      description = ''
        Opacity change between fade steps (in and out).
      '';
    };

    fadeExclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "window_type *= 'menu'"
        "name ~= 'Firefox$'"
        "focused = 1"
      ];
      description = ''
        List of conditions of windows that should not be faded.
        See `picom(1)` man page for more examples.
      '';
    };

    shadow = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Draw window shadows.
      '';
    };

    shadowOffsets = lib.mkOption {
      type = pairOf lib.types.int;
      default = [
        (-15)
        (-15)
      ];
      example = [
        (-10)
        (-15)
      ];
      description = ''
        Left and right offset for shadows (in pixels).
      '';
    };

    shadowOpacity = lib.mkOption {
      type = lib.types.numbers.between 0 1;
      default = 0.75;
      example = 0.8;
      description = ''
        Window shadows opacity.
      '';
    };

    shadowExclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "window_type *= 'menu'"
        "name ~= 'Firefox$'"
        "focused = 1"
      ];
      description = ''
        List of conditions of windows that should have no shadow.
        See `picom(1)` man page for more examples.
      '';
    };

    activeOpacity = lib.mkOption {
      type = lib.types.numbers.between 0 1;
      default = 1.0;
      example = 0.8;
      description = ''
        Opacity of active windows.
      '';
    };

    inactiveOpacity = lib.mkOption {
      type = lib.types.numbers.between 0.1 1;
      default = 1.0;
      example = 0.8;
      description = ''
        Opacity of inactive windows.
      '';
    };

    menuOpacity = lib.mkOption {
      type = lib.types.numbers.between 0 1;
      default = 1.0;
      example = 0.8;
      description = ''
        Opacity of dropdown and popup menu.
      '';
    };

    wintypes = lib.mkOption {
      type = lib.types.attrs;
      default = {
        popup_menu = {
          opacity = cfg.menuOpacity;
        };
        dropdown_menu = {
          opacity = cfg.menuOpacity;
        };
      };
      defaultText = lib.literalExpression ''
        {
          popup_menu = { opacity = config.${opt.menuOpacity}; };
          dropdown_menu = { opacity = config.${opt.menuOpacity}; };
        }
      '';
      example = { };
      description = ''
        Rules for specific window types.
      '';
    };

    opacityRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "95:class_g = 'URxvt' && !_NET_WM_STATE@:32a"
        "0:_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
      ];
      description = ''
        Rules that control the opacity of windows, in format PERCENT:PATTERN.
      '';
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "egl"
        "glx"
        "xrender"
        "xr_glx_hybrid"
      ];
      default = "xrender";
      description = ''
        Backend to use: `egl`, `glx`, `xrender` or `xr_glx_hybrid`.
      '';
    };

    vSync = lib.mkOption {
      type =
        with lib.types;
        either bool (enum [
          "none"
          "drm"
          "opengl"
          "opengl-oml"
          "opengl-swc"
          "opengl-mswc"
        ]);
      default = false;
      apply =
        x:
        let
          res = x != "none";
          msg =
            "The type of services.picom.vSync has changed to bool:"
            + " interpreting ${x} as ${lib.boolToString res}";
        in
        if lib.isBool x then x else lib.warn msg res;

      description = ''
        Enable vertical synchronization. Chooses the best method
        (drm, opengl, opengl-oml, opengl-swc, opengl-mswc) automatically.
        The bool value should be used, the others are just for backwards compatibility.
      '';
    };

    settings =
      with lib.types;
      let
        scalar =
          oneOf [
            bool
            int
            float
            str
          ]
          // {
            description = "scalar types";
          };

        libConfig =
          oneOf [
            scalar
            (listOf libConfig)
            (attrsOf libConfig)
          ]
          // {
            description = "libconfig type";
          };

        topLevel = attrsOf libConfig // {
          description = ''
            libconfig configuration. The format consists of an attributes
            set (called a group) of settings. Each setting can be a scalar type
            (boolean, integer, floating point number or string), a list of
            scalars or a group itself
          '';
        };

      in
      lib.mkOption {
        type = topLevel;
        default = { };
        example = lib.literalExpression ''
          blur =
            { method = "gaussian";
              size = 10;
              deviation = 5.0;
            };
        '';
        description = ''
          Picom settings. Use this option to configure Picom settings not exposed
          in a NixOS option or to bypass one.  For the available options see the
          CONFIGURATION FILES section at `picom(1)`.
        '';
      };
  };

  config = lib.mkIf cfg.enable {
    services.picom.settings = mkDefaultAttrs {
      # fading
      fading = cfg.fade;
      fade-delta = cfg.fadeDelta;
      fade-in-step = lib.elemAt cfg.fadeSteps 0;
      fade-out-step = lib.elemAt cfg.fadeSteps 1;
      fade-exclude = cfg.fadeExclude;

      # shadows
      shadow = cfg.shadow;
      shadow-offset-x = lib.elemAt cfg.shadowOffsets 0;
      shadow-offset-y = lib.elemAt cfg.shadowOffsets 1;
      shadow-opacity = cfg.shadowOpacity;
      shadow-exclude = cfg.shadowExclude;

      # opacity
      active-opacity = cfg.activeOpacity;
      inactive-opacity = cfg.inactiveOpacity;

      wintypes = cfg.wintypes;

      opacity-rule = cfg.opacityRules;

      # other options
      backend = cfg.backend;
      vsync = cfg.vSync;
    };

    systemd.user.services.picom = {
      description = "Picom composite manager";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];

      # Temporarily fixes corrupt colours with Mesa 18
      environment = lib.mkIf (cfg.backend == "glx") {
        allow_rgb10_configs = "false";
      };

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} --config ${configFile}";
        RestartSec = 3;
        Restart = "always";
      };
    };

    environment.systemPackages = [ cfg.package ];
  };

  meta.maintainers = with lib.maintainers; [ rnhmjoj ];

}
