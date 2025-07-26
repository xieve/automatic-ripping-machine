{
  lib,
  src,
  python3Packages,
  # local
  pydvdid,
  # runtime deps
  bash,
  curl,
  eject,
  lsdvd,
  systemd,
  util-linux,
}:

let
  version = builtins.replaceStrings [ "\n" ] [ "" ] (lib.readFile "${src}/VERSION");
in
python3Packages.buildPythonApplication {
  inherit src version;
  pname = "automatic-ripping-machine";
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];

  preBuild =
    let
      cfgPath = "/etc/arm";
    in
    ''
      ${lib.concatMapAttrsStringSep ""
        (targetPath: srcPath: ''
          install --no-target-directory -D ${srcPath} $out/${targetPath}
        '')
        {
          "bin/armui" = "arm/runui.py";
          "bin/arm" = "arm/ripper/main.py";
          "lib/arm/setup/arm.yaml" = "setup/arm.yaml";
          "lib/arm/arm/ui/comments.json" = "arm/ui/comments.json";
          "lib/arm/VERSION" = "VERSION";
        }
      }
      cp -r arm/migrations $out/lib/arm/arm

      mkdir -p $out/lib/udev/rules.d
      echo 'ACTION=="change", KERNEL=="s[rg][0-9]*",' \
        'RUN{program}+="${systemd}/bin/systemd-mount --no-block --automount=yes --collect $devnode /run/arm$devnode",' \
        'ENV{SYSTEMD_WANTS}+="arm@$kernel.service"' \
        > $out/lib/udev/rules.d/50-automatic-ripping-machine.rules
    '';

  # Provide runtime dependencies by injecting them into PATH via the python wrapper
  makeWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath [
        # These will be provided dynamically by the module depending on the configuration
        # abcde
        # ffmpeg-headless # Only required for ripping posters
        # handbrake
        bash
        curl
        eject
        lsdvd
        util-linux # mount, umount, findmnt
      ]
    }"
  ];

  dependencies = with python3Packages; [
    psutil
    pyudev
    alembic
    apprise
    bcrypt
    discid
    flask
    flask-cors
    flask-login
    flask-migrate
    flask-sqlalchemy
    flask-wtf
    greenlet
    idna
    itsdangerous
    jinja2
    mako
    markdown
    markupsafe
    musicbrainzngs
    netifaces
    prettytable
    psutil
    pydvdid
    pyyaml
    pyudev
    requests
    sqlalchemy
    urllib3
    waitress
    werkzeug
    wtforms
    xmltodict
  ];
}
