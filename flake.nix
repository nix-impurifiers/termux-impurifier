# SPDX-License-Identifier: MIT
{
  description = "Native Termux packages from Nix-built Android inputs";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/09063bd1f2b36fd9fd793c36dfade7bd40a93dfc";
    android-impurifier = {
      url = "github:nix-impurifiers/android-impurifier";
      flake = false;
    };
    caisson.url = "github:nix-caisson/caisson";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };
  outputs =
    inputs@{ caisson, ... }:
    let
      lib = caisson.lib.caisson.mkLib {
        inherit (caisson.lib.caisson.pins.flake inputs) sources root;
        name = "termux-impurifier";
        defaultEcosystemSrc = sources: { nixpkgs-lib = sources.nixpkgs; };
        systems = [ "x86_64-linux" ];
        projects = { inherit caisson; };
        configs = lib: lib.caisson.mkModules ./configs;
        pkgSets = lib: lib.caisson.nixpkgs.mkConfigurations { };
      };
    in
    lib.caisson.flake-parts.mkTopConfiguration { };
}
