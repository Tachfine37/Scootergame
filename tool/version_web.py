"""Give the web entry points content-based names for reliable Pages updates."""
import hashlib
from pathlib import Path
import re


def main():
    root = Path(__file__).resolve().parents[1] / 'build' / 'web'
    script = root / 'main.dart.js'
    version = hashlib.sha256(script.read_bytes()).hexdigest()[:12]
    app_name = f'main.dart.{version}.js'
    (root / app_name).write_bytes(script.read_bytes())
    bootstrap = (root / 'flutter_bootstrap.js').read_text(encoding='utf-8')
    if 'main.dart.js' not in bootstrap:
        raise SystemExit('Flutter bootstrap format changed: main.dart.js missing')
    bootstrap = bootstrap.replace('main.dart.js', app_name)
    bootstrap_name = f'flutter_bootstrap.{version}.js'
    (root / bootstrap_name).write_text(bootstrap, encoding='utf-8')
    index = (root / 'index.html').read_text(encoding='utf-8')
    if 'src="flutter_bootstrap.js"' not in index:
        raise SystemExit('Flutter index format changed: bootstrap script missing')
    index = index.replace('src="flutter_bootstrap.js"', f'src="{bootstrap_name}"')
    index = re.sub(r'<title>.*?</title>', '<title>One More Parcel? · Endless Ride</title>', index)
    index = index.replace('content="A new Flutter project."',
                          'content="An endless delivery ride. Balance your parcels, repair your scooter, and beat your best score."')
    (root / 'index.html').write_text(index, encoding='utf-8')
    print(f'Web version: {version}')


if __name__ == '__main__':
    main()
