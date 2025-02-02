{ mkDerivation, lib, fetchzip, buildEnv, makeDesktopItem, runCommand, writeText, pkg-config
, cmake, qmake, cacert, jsoncpp, libX11, libXScrnSaver, lua, openssl, poco
, qtbase, qtwebengine, qtx11extras, sqlite }:

let
  name = "toggldesktop-${version}";
  version = "7.4.231";

  src = fetchzip {
    url = "https://github.com/toggl/toggldesktop/archive/v${version}.tar.gz";
    sha256 = "01hqkx9dljnhwnyqi6mmzfp02hnbi2j50rsfiasniqrkbi99x9v1";
  };

  bugsnag-qt = mkDerivation rec {
    pname = "bugsnag-qt";
    version = "20180522.005732";

    src = fetchzip {
      url = "https://github.com/alpakido/bugsnag-qt/archive/${version}.tar.gz";
      sha256 = "02s6mlggh0i4a856md46dipy6mh47isap82jlwmjr7hfsk2ykgnq";
    };

    nativeBuildInputs = [ qmake ];
    buildInputs = [ qtbase ];
  };

  qxtglobalshortcut = mkDerivation rec {
    pname = "qxtglobalshortcut";
    version = "f584471dada2099ba06c574bdfdd8b078c2e3550";

    src = fetchzip {
      url = "https://github.com/hluk/qxtglobalshortcut/archive/${version}.tar.gz";
      sha256 = "1iy17gypav10z8aa62s5jb6mq9y4kb9ms4l61ydmk3xwlap7igw1";
    };

    nativeBuildInputs = [ cmake ];
    buildInputs = [ qtbase qtx11extras ];
  };

  qt-oauth-lib = mkDerivation rec {
    pname = "qt-oauth-lib";
    version = "20190125.190943";

    src = fetchzip {
      url = "https://github.com/alpakido/qt-oauth-lib/archive/${version}.tar.gz";
      sha256 = "0zmfgvdf6n79mgfvbda7lkdxxlzjmy86436gqi2r5x05vq04sfrj";
    };

    nativeBuildInputs = [ qmake ];
    buildInputs = [ qtbase qtwebengine ];
  };

  poco-pc = writeText "poco.pc" ''
    Name: Poco
    Description: ${poco.meta.description}
    Version: ${poco.version}
    Libs: -L${poco}/lib -lPocoDataSQLite -lPocoData -lPocoNet -lPocoNetSSL -lPocoCrypto -lPocoUtil -lPocoXML -lPocoFoundation
    Cflags: -I${poco}/include/Poco
  '';

  poco-pc-wrapped = runCommand "poco-pc-wrapped" {} ''
    mkdir -p $out/lib/pkgconfig && ln -s ${poco-pc} $_/poco.pc
  '';

  libtoggl = mkDerivation {
    name = "libtoggl-${version}";
    inherit src version;

    sourceRoot = "source/src";

    nativeBuildInputs = [ qmake pkg-config ];
    buildInputs = [ jsoncpp lua openssl poco poco-pc-wrapped sqlite libX11 ];

    postPatch = ''
      cat ${./libtoggl.pro} > libtoggl.pro
      rm get_focused_window_{mac,windows}.cc
    '';
  };

  toggldesktop = mkDerivation {
    name = "${name}-unwrapped";
    inherit src version;

    sourceRoot = "source/src/ui/linux/TogglDesktop";

    postPatch = ''
      substituteAll ${./TogglDesktop.pro} TogglDesktop.pro
      substituteInPlace toggl.cpp \
        --replace ./../../../toggl_api.h toggl_api.h
    '';

    postInstall = ''
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt $out/cacert.pem
    '';

    nativeBuildInputs = [ qmake pkg-config ];

    buildInputs = [
      bugsnag-qt
      libtoggl
      qxtglobalshortcut
      qtbase
      qtwebengine
      qt-oauth-lib
      qtx11extras
      libX11
      libXScrnSaver
    ];
  };

  toggldesktop-icons = mkDerivation {
    name = "${name}-icons";
    inherit (toggldesktop) src sourceRoot;

    installPhase = ''
      for f in icons/*; do
        mkdir -p $out/share/icons/hicolor/$(basename $f)/apps
        mv $f/toggldesktop.png $_
      done
    '';
  };

  toggldesktop-wrapped = runCommand "toggldesktop-wrapped" {} ''
    mkdir -p $out/bin && ln -s ${toggldesktop}/toggldesktop $_
  '';

  desktopItem = makeDesktopItem rec {
    categories = "Utility;";
    desktopName = "Toggl";
    genericName = desktopName;
    name = "toggldesktop";
    exec = "${toggldesktop-wrapped}/bin/toggldesktop";
    icon = "toggldesktop";
  };
in

buildEnv {
  inherit name;
  paths = [ desktopItem toggldesktop-icons toggldesktop-wrapped ];

  meta = with lib; {
    broken = true; # libtoggl is broken
    description = "Client for Toggl time tracking service";
    homepage = "https://github.com/toggl/toggldesktop";
    license = licenses.bsd3;
    maintainers = with maintainers; [ yana ];
    platforms = platforms.linux;
  };
}
