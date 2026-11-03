# SPDX-License-Identifier: MIT
{ pkgs }:
let
  inherit (pkgs) lib;
  # payload is already compiled for Android and laid out relative to Termux PREFIX.
  # This adapter does not relocate binaries or create an Android application.
  makeNativePackage =
    {
      payload,
      name,
      version,
      architecture,
      dependencies ? [ ],
      applicationId ? "com.termux",
      description ? "Nix-built native Termux payload",
    }:
    assert lib.assertMsg (
      builtins.match "[a-z0-9][a-z0-9+.-]+" name != null
    ) "invalid Termux package name";
    assert lib.assertMsg (lib.elem architecture [
      "aarch64"
      "arm"
      "i686"
      "x86_64"
      "all"
    ]) "unsupported Termux architecture";
    assert lib.assertMsg (
      builtins.match "[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+" applicationId != null
    ) "invalid Termux application ID";
    pkgs.runCommand "${name}-${version}-termux.deb"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.dpkg
          pkgs.gnutar
          pkgs.xz
          pkgs.binutils
        ];
        specification = builtins.toJSON {
          inherit
            payload
            name
            version
            architecture
            dependencies
            applicationId
            description
            ;
        };
        passAsFile = [ "specification" ];
      }
      ''
        python3 ${./package.py} "$specificationPath" "$out"
      '';
in
{
  inherit makeNativePackage;
  makePackage = makeNativePackage;
  nativeBuilder = pkgs.dpkg;
}
