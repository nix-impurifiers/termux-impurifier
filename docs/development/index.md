# Development

Run `nix flake check -L`. The native VM uses the Android backend's pinned software
QEMU harness and Android-x86 image, plus Termux 0.118.3's x86_64 APK by hash.
Termux installs its own embedded bootstrap. Package operations use `run-as
com.termux` and the app's actual Android-native dpkg. The fixture has no target
Nix store or database. The producer fixture is a PIE executable compiled for
Android, using `/system/bin/linker64` and direct syscalls without libc. It reads
a file from a required native package, so dependency retention affects execution.

The host DEB assembler may warn about `x86_64`: Termux's patched dpkg uses this
architecture name, whereas ordinary Debian dpkg forbids underscores. Do not map
it to Debian's `amd64`; the target native manager is authoritative.

Payloads use explicit native layouts and ABI metadata. No implicit host-runtime
requirements, package scripts, relocation or Nix provisioning are added. Tests
must continue using the app UID, actual package checksums and dependency policy.
