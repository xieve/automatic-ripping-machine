self:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    getExe
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optionalString
    ;
  arm = self.packages.${pkgs.system}.automatic-ripping-machine;
  json = pkgs.formats.json { };
  ini = pkgs.formats.iniWithGlobalSection { };
  cfg = config.services.automatic-ripping-machine;
  ARM_CONFIG_FILE = json.generate "arm.yaml" cfg.settings;
  appriseFile = json.generate "apprise.yaml" cfg.appriseSettings;
  abcdeFile = ini.generate "abcde.conf" { globalSection = cfg.abcdeSettings; };
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

    handbrakePackage = mkPackageOption pkgs "handbrake" { };

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
    services.automatic-ripping-machine.settings =
      let
        # Workaround for https://github.com/NixOS/nixpkgs/issues/244934
        HANDBRAKE_CLI = optionalString cfg.enableTranscoding "/usr/bin/env \"LD_LIBRARY_PATH=/run/opengl-driver/lib:$LD_LIBRARY_PATH\" '${getExe cfg.handbrakePackage}'";
      in
      {
        inherit HANDBRAKE_CLI;
        HANDBRAKE_LOCAL = HANDBRAKE_CLI;
        DBFILE = "/var/lib/arm/arm.db";
        LOGPATH = "/var/log/arm/";
        INSTALLPATH = "${arm}/lib/arm/";
        SKIP_TRANSCODE = !cfg.enableTranscoding;
        ABCDE_CONFIG_FILE = abcdeFile;
        APPRISE = mkIf (cfg.appriseSettings != { }) appriseFile;
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
          inherit ARM_CONFIG_FILE;
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        };
        serviceConfig = {
          inherit BindPaths;
          Type = "exec";
          User = "arm";
          Restart = "always";
          RestartSec = "3";
          ExecStart = "${arm}/bin/armui";
          ProtectHome = true;
          ProtectSystem = "strict"; # Enforce read-only access for the entire system except for:
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
        # Load SCSI kernel module
        # Needed for some (?) BluRay drives
        wants = [ "modprobe@sg.service" ];
        after = [ "modprobe@sg.service" ];
        path = [
          pkgs.makemkv
        ];
        environment = {
          inherit ARM_CONFIG_FILE;
        };
        # confinement.enable = true;
        serviceConfig = {
          User = "arm";
          ExecStart = ''
            ${arm}/bin/arm --no-syslog --devpath "%I"
          '';
          ProtectSystem = "strict";
          ProtectHome = true;
          StateDirectory = "arm"; # /var/lib/arm
          LogsDirectory = "arm";
          ReadWritePaths = BindPaths;
          RuntimeDirectory = "arm";
          # TODO: it would be better to only allow access to the necessary device (if possible?)
          DeviceAllow = [
            "char-sg rw"
            "/dev/%I r"
          ];
          # DeviceAllow = [ "/dev/%I rw" ]; #"block-sr rw";
          # BindPaths = BindPaths ++ [ "/dev/%I" ];
          PrivateTmp = true;
        };
      };
    };
  };
}
