self:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatMapAttrs
    getExe
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkOption
    optional
    optionalString
    ;
  inherit (pkgs) writeShellScript;
  arm = self.packages.${pkgs.system}.automatic-ripping-machine;
  json = pkgs.formats.json { };
  ini = pkgs.formats.iniWithGlobalSection { };
  cfg = config.services.automatic-ripping-machine;
  cfgFile = json.generate "arm.yaml" cfg.settings;
  appriseFile = json.generate "apprise.yaml" cfg.appriseSettings;
  abcdeFile = ini.generate "abcde.conf" { globalSection = cfg.abcdeSettings; };
  cfgPath = "/etc/arm";
  BindPaths = with cfg.settings; [
    RAW_PATH
    TRANSCODE_PATH
    COMPLETED_PATH
  ];
in
{
  options.services.automatic-ripping-machine = with lib.types; {
    enable = mkEnableOption "Automatic Ripping Machine";

    user = mkOption {
      type = str;
      default = "arm";
    };

    group = mkOption {
      type = str;
      default = "media";
    };

    enableTranscoding = mkOption {
      description = ''
        Whether to enable automatic transcoding using HandBrake. When disabled, HandBrake will not
        be pulled in as a dependency.
      '';
      type = bool;
      default = true;
      example = false;
    };

    settings = mkOption {
      description = "Settings for ARM. Will be used to generate arm.yaml.";
      inherit (json) type;
      default = { };
      example = {
        DISABLE_LOGIN = true;
        DATE_FORMAT = "%Y-%m-%d %H:%M:%S";
        RAW_PATH = "/mnt/tank/raw/";
        TRANSCODE_PATH = "/mnt/tank/transcoded/";
        COMPLETED_PATH = "/mnt/tank/completed/";
        LOGLEVEL = "DEBUG";
      };
    };

    appriseSettings = mkOption {
      description = "Settings for Apprise. Will be used to generate apprise.yaml.";
      inherit (json) type;
      default = { };
    };

    abcdeSettings = mkOption {
      description = "Settings for abcde. Will be used to generate abcde.yaml.";
      type = attrsOf ini.lib.types.atom;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    # Needed for MakeMKV
    boot.kernelModules = [ "sg" ];

    services.automatic-ripping-machine.settings =
      let
        # Workaround for https://github.com/NixOS/nixpkgs/issues/244934
        HANDBRAKE_CLI = optionalString cfg.enableTranscoding
          "/usr/bin/env \"LD_LIBRARY_PATH=/run/opengl-driver/lib:$LD_LIBRARY_PATH\" '${getExe pkgs.handbrake}'";
      in
      {
        inherit HANDBRAKE_CLI;
        HANDBRAKE_LOCAL = HANDBRAKE_CLI;
        DBFILE = "/var/lib/arm/arm.db";
        LOGPATH = "/var/log/arm/";
        INSTALLPATH = "${arm}/lib/arm/";
        SKIP_TRANSCODE = !cfg.enableTranscoding;
      };

    users = {
      users.${cfg.user} = {
        inherit (cfg) group;
        extraGroups = [ "cdrom" ];
        home = mkDefault "/var/lib/arm";
        isSystemUser = mkDefault true;
      };
      groups.${cfg.group} = { };
    };

    services.udev.packages = [ arm ];

    systemd = {
      services.armui = {
        description = "Automatic Ripping Machine Web UI";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        # confinement = {
        #   enable = true;
        #   packages =
        #     with pkgs;
        #     [
        #       abcdeFile
        #       appriseFile
        #       cacert
        #       cfgFile
        #     ]
        #     ++ optional cfg.enableTranscoding handbrake;
        # };
        environment = {
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        serviceConfig = {
          inherit BindPaths;
          Type = "exec";
          User = "arm";
          Restart = "always";
          RestartSec = "3";
          ExecStart = "${arm}/bin/armui";
          ProtectSystem = "strict"; # Enforce read-only access for the entire system except for:
          ProtectHome = true;
          ConfigurationDirectory = "arm"; # /etc/arm
          StateDirectory = "arm"; # /var/lib/arm
          LogsDirectory = [
            "arm"
            "arm/progress"
          ]; # /var/log/arm
          DeviceAllow = [ "block-sr rw" ];
          PrivateTmp = true;
        };
      };

      services."arm@" = {
        description = "Automatic Ripping Machine Worker";
        path = [
          pkgs.makemkv
        ];
        # confinement.enable = true;
        serviceConfig = {
          User = "arm";
          ExecStart = ''
            ${arm}/bin/arm --no-syslog --devpath "%I"
          '';
          ProtectSystem = "strict";
          ProtectHome = true;
          ConfigurationDirectory = "arm";
          StateDirectory = "arm"; # /var/lib/arm
          LogsDirectory = "arm";
          ReadWritePaths = BindPaths ++ [ "/dev/%I" ];
          RuntimeDirectory = "arm";
          # DeviceAllow = [ "/dev/%I rw" ]; #"block-sr rw";
          # BindPaths = BindPaths ++ [ "/dev/%I" ];
          PrivateTmp = true;
        };
      };

      tmpfiles.settings = {
        "50-automatic-ripping-machine" = {
          "${cfgPath}/arm.yaml"."L+".argument = "${cfgFile}";
          "${cfgPath}/apprise.yaml"."L+".argument = "${appriseFile}";
          "${cfgPath}/abcde.conf"."L+".argument = "${abcdeFile}";
        };
      };
    };
  };
}
