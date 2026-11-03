# SPDX-License-Identifier: MIT
{ ... }:
{ lib, inputs, ... }:
{
  flake.lib = lib.mkForce {
    termux-impurifier = { pkgs }: import ../../../nix { inherit pkgs; };
  };
  perSystem =
    { pkgs, ... }:
    let
      backend = import ../../../nix { inherit pkgs; };
    in
    {
      packages.default = backend.makeNativePackage {
        name = "nix-built-hello";
        version = "1";
        architecture = "all";
        payload = pkgs.runCommand "termux-hello" { } ''
          mkdir -p $out/bin
          printf '#!/system/bin/sh\necho hello-from-nix\n' > $out/bin/nix-built-hello
          chmod 755 $out/bin/nix-built-hello
        '';
      };
      checks.native-vm = import ../../../tests/lifecycle.nix {
        inherit pkgs backend;
        androidSrc = inputs.android-impurifier;
      };
      formatter = pkgs.nixfmt-tree;
    };
}
