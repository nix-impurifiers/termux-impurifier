# SPDX-License-Identifier: MIT
{
  pkgs,
  backend,
  androidSrc,
}:
let
  image = import (androidSrc + "/nix/image.nix") { inherit pkgs; };
  fixtures = import ./fixture.nix { inherit pkgs backend; };
  termux = pkgs.fetchurl {
    url = "https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3%2Bgithub-debug_x86_64.apk";
    hash = "sha256-NVDmH02etJtxL9G9lRncNwhaTY61l8V6NA8KZIWbcUQ=";
  };
in
pkgs.runCommand "termux-android-native-package-lifecycle"
  {
    nativeBuildInputs = [
      pkgs.qemu
      pkgs.android-tools
      pkgs.python3
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export TERMUX_APK=${termux} TERMUX_FIXTURES=${fixtures}
    python3 ${androidSrc}/tests/probe.py ${image} ${image.iso} ${./lifecycle.py}
    touch "$out"
  ''
