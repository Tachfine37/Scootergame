"""Generate missing native wrappers using the installed official Flutter SDK.

The game code, dependencies and existing native folders are never overwritten.
Run from any directory: python3 tool/bootstrap_platforms.py --platforms ios,web
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from build_game_audio import main as build_audio


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platforms', default='ios,android,web')
    options = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    requested = options.platforms.split(',')
    if not requested or any(p not in {'ios', 'android', 'web'} for p in requested):
        raise SystemExit('Platforms must be ios,android,web (a subset is allowed).')
    build_audio()
    missing = [p for p in requested if not (root / p).exists()]
    if not missing:
        print('Native wrappers already exist; preserving them.')
        return
    flutter = os.environ.get('CA_PASSE_FLUTTER') or shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter is not on PATH. Install Flutter 3.41+ first.')
    with tempfile.TemporaryDirectory(prefix='ca-passe-wrapper-') as temporary:
        generated = Path(temporary) / 'ca_passe'
        subprocess.run([flutter, 'create', '--no-pub', '--platforms=' + ','.join(missing),
                        '--project-name=ca_passe', '--org=com.tachfine37',
                        str(generated)], check=True)
        for platform in missing:
            shutil.copytree(generated / platform, root / platform)
        metadata = generated / '.metadata'
        if metadata.exists() and not (root / '.metadata').exists():
            shutil.copy2(metadata, root / '.metadata')
    print('Generated: ' + ', '.join(missing))


if __name__ == '__main__':
    main()
