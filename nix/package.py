# SPDX-License-Identifier: MIT
"""Build a Termux DEB with native prefix ownership and installed-file checksums."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys

configuration, output = map(Path, sys.argv[1:])
spec = json.loads(configuration.read_text())
if not re.fullmatch(r'[0-9][A-Za-z0-9.+:~\-]*', spec['version']):
    raise ValueError('invalid native package version')
if '\n' in spec['description'] or '\r' in spec['description']:
    raise ValueError('package description must be one line')
for dependency in spec['dependencies']:
    if not re.fullmatch(r'[a-z0-9][a-z0-9+.-]+(?: \((?:<<|<=|=|>=|>>) [0-9][A-Za-z0-9.+:~\-]*\))?', dependency):
        raise ValueError('invalid Termux dependency expression')
root = Path('package')
prefix = root / 'data/data' / spec['applicationId'] / 'files/usr'
prefix.parent.mkdir(parents=True)
shutil.copytree(spec['payload'], prefix, symlinks=True)
# Nix outputs are read-only; native rootless unpack/upgrade needs writable owners.
for entry in [prefix, *prefix.rglob('*')]:
    if not entry.is_symlink():
        entry.chmod(stat.S_IMODE(entry.stat().st_mode) | stat.S_IWUSR)
control = root / 'DEBIAN'
control.mkdir()
metadata = (f'Package: {spec["name"]}\nVersion: {spec["version"]}\nArchitecture: {spec["architecture"]}\n'
            'Maintainer: nix-impurifiers <root@localhost>\n'
            f'Description: {spec["description"]}\n')
if spec['dependencies']:
    metadata += 'Depends: ' + ', '.join(spec['dependencies']) + '\n'
(control / 'control').write_text(metadata)
checksums = []
for entry in sorted(prefix.rglob('*')):
    if entry.is_file() and not entry.is_symlink():
        with entry.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'md5').hexdigest()
        checksums.append(digest + '  ' + entry.relative_to(root).as_posix())
(control / 'md5sums').write_text('\n'.join(checksums) + '\n')
# Keep Android app-data and Termux PREFIX directory metadata out of package ownership.
# Let dpkg-deb generate native control metadata, then replace only its data member.
intermediate = Path('native.deb')
subprocess.run(['dpkg-deb', '--root-owner-group', '-Zxz', '--build', str(root), str(intermediate)], check=True)
entries = [entry.relative_to(root).as_posix() for entry in sorted(prefix.iterdir())]
command = ['tar', '--sort=name', '--mtime=@1', '--owner=0', '--group=0', '--numeric-owner',
           '-C', str(root), '-cJf', 'data.tar.xz']
subprocess.run(command + (['--', *entries] if entries else ['--files-from', '/dev/null']), check=True)
subprocess.run(['ar', 'rD', str(intermediate), 'data.tar.xz'], check=True)
shutil.copyfile(intermediate, output)
