# SPDX-License-Identifier: MIT
"""Use the actual Termux app UID and Android-native dpkg, without a host Nix store."""
import os
from pathlib import Path
import shlex
import time

prefix = '/data/data/com.termux/files/usr'
adb('install', os.environ['TERMUX_APK'])
adb('shell', 'am', 'start', '-n', 'com.termux/.app.TermuxActivity')
def termux(command, check=True):
    result = adb('shell', 'run-as', 'com.termux', '/system/bin/sh', '-c',
               'export PREFIX=' + prefix + '; export PATH=$PREFIX/bin:/system/bin; export LD_LIBRARY_PATH=$PREFIX/lib; export TMPDIR=$PREFIX/tmp; export HOME=/data/data/com.termux/files/home; ' + command, check=False)
    if check and result.returncode:
        raise AssertionError('Termux command failed: ' + command + '\n' + result.stdout + result.stderr)
    return result

deadline = time.monotonic() + 180
while time.monotonic() < deadline:
    status = termux('test -x "$PREFIX/bin/dpkg"', check=False)
    if 'not debuggable' in status.stderr:
        raise AssertionError(status.stderr)
    if status.returncode == 0:
        break
    time.sleep(2)
else:
    print('Termux bootstrap status:', status.stdout, status.stderr, flush=True)
    print(adb('logcat', '-d', '-s', 'Termux:*', 'TermuxInstaller:*', '*:S').stdout, flush=True)
    print(termux('ls -la files "$PREFIX"', check=False).stdout, flush=True)
    raise AssertionError('Termux did not install its embedded bootstrap')
termux('dpkg --version')
private_directories = 'stat -c %a /data/data/com.termux /data/data/com.termux/files "$PREFIX"'
original_modes = termux(private_directories).stdout
for name in ['data', 'one', 'two']:
    adb('push', str(Path(os.environ['TERMUX_FIXTURES']) / (name + '.deb')), '/data/local/tmp/' + name + '.deb')
termux('dpkg -i /data/local/tmp/data.deb /data/local/tmp/one.deb')
assert termux(private_directories).stdout == original_modes
assert 'native-proof-1' in termux('native-proof').stdout
assert 'retained-native-dependency' in termux('native-proof').stdout
assert not termux('dpkg -V native-proof native-proof-data').stdout.strip()
termux('cp -p "$PREFIX/bin/native-proof" "$PREFIX/tmp/proof.backup"; echo changed >> "$PREFIX/bin/native-proof"')
assert 'native-proof' in termux('dpkg -V native-proof').stdout
termux('cp -p "$PREFIX/tmp/proof.backup" "$PREFIX/bin/native-proof"')
assert not termux('dpkg -V native-proof').stdout.strip()
termux('dpkg -i /data/local/tmp/two.deb')
assert termux(private_directories).stdout == original_modes
assert 'native-proof-2' in termux('native-proof').stdout
assert termux('dpkg --remove native-proof-data', check=False).returncode != 0
termux('dpkg --purge native-proof')
termux('test ! -e "$PREFIX/bin/native-proof"; test -e "$PREFIX/share/native-proof/value"')
termux('dpkg --purge native-proof-data')
termux('test ! -e "$PREFIX/share/native-proof/value"; test ! -e /nix')
adb('shell', 'pm', 'uninstall', 'com.termux')
print('TERMUX_NATIVE_PACKAGE_LIFECYCLE_OK', flush=True)
