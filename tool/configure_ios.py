"""Apply this game's iOS metadata after Flutter generates the Xcode wrapper."""
import os
from pathlib import Path
import plistlib
import re


def main():
    root = Path(__file__).resolve().parents[1]
    bundle_id = os.environ.get('BUNDLE_ID', 'com.tachfine37.scootergame')
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}', bundle_id):
        raise SystemExit('BUNDLE_ID must be a valid reverse-domain identifier.')
    project = root / 'ios/Runner.xcodeproj/project.pbxproj'
    contents = project.read_text(encoding='utf-8')
    def replace(match):
        suffix = '.RunnerTests' if 'RunnerTests' in match.group(1) else ''
        return 'PRODUCT_BUNDLE_IDENTIFIER = ' + bundle_id + suffix + ';'
    contents, count = re.subn(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', replace, contents)
    if count == 0:
        raise SystemExit('No bundle identifier found in the generated Xcode project.')
    project.write_text(contents, encoding='utf-8')
    info_path = root / 'ios/Runner/Info.plist'
    with info_path.open('rb') as stream:
        info = plistlib.load(stream)
    info['CFBundleDisplayName'] = 'One More Parcel?'
    info['CFBundleName'] = 'OneMoreParcel'
    info['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
    info['UISupportedInterfaceOrientations~ipad'] = ['UIInterfaceOrientationPortrait']
    info['UIRequiresFullScreen'] = True
    # This prototype has no custom cryptography or encrypted application data.
    info['ITSAppUsesNonExemptEncryption'] = False
    with info_path.open('wb') as stream:
        plistlib.dump(info, stream, sort_keys=False)
    print('iOS configured for ' + bundle_id)


if __name__ == '__main__':
    main()
