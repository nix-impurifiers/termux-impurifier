# SPDX-License-Identifier: MIT
{ pkgs, backend }:
let
  make =
    version:
    backend.makeNativePackage {
      name = "native-proof";
      inherit version;
      architecture = "x86_64";
      dependencies = [ "native-proof-data (= 1)" ];
      payload =
        pkgs.runCommand "termux-native-proof-${version}"
          {
            nativeBuildInputs = [
              pkgs.llvmPackages.clang-unwrapped
              pkgs.llvmPackages.lld
            ];
          }
          ''
            mkdir -p $out/bin
            cat > proof.c <<'C'
            static long call(long number, long a, long b, long c, long d) {
              register long fourth __asm__("r10") = d;
              long result;
              __asm__ volatile("syscall" : "=a"(result) : "a"(number), "D"(a), "S"(b), "d"(c), "r"(fourth) : "rcx", "r11", "memory");
              return result;
            }
            __attribute__((noreturn)) void _start(void) {
              static const char message[] = "native-proof-${version}\n";
              static const char path[] = "/data/data/com.termux/files/usr/share/native-proof/value";
              char buffer[128];
              call(1, 1, (long)message, sizeof(message)-1, 0);
              long fd = call(257, -100, (long)path, 0, 0);
              long count = fd < 0 ? -1 : call(0, fd, (long)buffer, sizeof(buffer), 0);
              if (count > 0) call(1, 1, (long)buffer, count, 0);
              if (fd >= 0) call(3, fd, 0, 0, 0);
              call(231, count > 0 ? 0 : 1, 0, 0, 0);
              __builtin_unreachable();
            }
            C
            clang --target=x86_64-linux-android28 -fuse-ld=lld -nostdlib -fPIE -pie -O2 \
              -Wl,-e,_start -Wl,--dynamic-linker,/system/bin/linker64 proof.c -o $out/bin/native-proof
          '';
    };
  data = backend.makeNativePackage {
    name = "native-proof-data";
    version = "1";
    architecture = "all";
    payload = pkgs.runCommand "termux-native-proof-data" { } ''
      mkdir -p $out/share/native-proof
      echo retained-native-dependency > $out/share/native-proof/value
    '';
  };
in
pkgs.runCommand "termux-native-package-fixtures" { } ''
  mkdir -p $out
  cp ${data} $out/data.deb
  cp ${make "1"} $out/one.deb
  cp ${make "2"} $out/two.deb
''
