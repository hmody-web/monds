from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    s = manifest.read_text(encoding='utf-8')
    if 'android.permission.INTERNET' not in s:
        s = s.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.INTERNET" />\n'
            '    <uses-permission android:name="android.permission.CAMERA" />',
        )
    elif 'android.permission.CAMERA' not in s:
        s = s.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.CAMERA" />',
        )
    s = re.sub(r'android:label="[^"]*"', 'android:label="مندس"', s, count=1)
    manifest.write_text(s, encoding='utf-8')

plist = root / 'ios/Runner/Info.plist'
if plist.exists():
    import plistlib

    with plist.open('rb') as f:
        data = plistlib.load(f)

    # الاسم الظاهر على النظام يجب أن يبقى عربياً دائماً.
    data['CFBundleDisplayName'] = 'مندس'
    data['CFBundleName'] = 'مندس'
    data['NSCameraUsageDescription'] = (
        'يستخدم مندس الكاميرا لمسح رمز QR والانضمام إلى غرفة أصدقائك.'
    )

    # تنظيف أي مفاتيح صلاحية كاميرا أضيفت بالخطأ داخل UIScene سابقاً.
    scene = data.get('UIApplicationSceneManifest')
    if isinstance(scene, dict):
        scene.pop('NSCameraUsageDescription', None)
        configs = scene.get('UISceneConfigurations')
        if isinstance(configs, dict):
            configs.pop('NSCameraUsageDescription', None)
            for entries in configs.values():
                if isinstance(entries, list):
                    for entry in entries:
                        if isinstance(entry, dict):
                            entry.pop('NSCameraUsageDescription', None)

    with plist.open('wb') as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_XML, sort_keys=False)

# Native splash: system screen is only the main app color.
storyboard = root / 'ios/Runner/Base.lproj/LaunchScreen.storyboard'
if storyboard.parent.exists():
    storyboard.write_text('''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21762" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies><deployment identifier="iOS"/><plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21754"/><capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/></dependencies>
    <scenes><scene sceneID="EHf-IW-A2E"><objects><viewController id="01J-lp-oVM" sceneMemberID="viewController"><view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3"><rect key="frame" x="0.0" y="0.0" width="393" height="852"/><autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/><color key="backgroundColor" red="0.1294117647" green="0.5843137255" blue="0.5294117647" alpha="1" colorSpace="custom" customColorSpace="sRGB"/></view></viewController><placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/></objects></scene></scenes>
</document>
''', encoding='utf-8')

res = root / 'android/app/src/main/res'
if res.exists():
    for folder in ['values', 'values-night', 'values-v31', 'values-night-v31', 'drawable', 'drawable-v21']:
        (res / folder).mkdir(parents=True, exist_ok=True)
    (res / 'values/colors.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources><color name="mundas_splash">#219587</color></resources>\n',
        encoding='utf-8',
    )
    launch = '<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:drawable="@color/mundas_splash" /></layer-list>\n'
    transparent = '<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="1dp" android:height="1dp" android:viewportWidth="1" android:viewportHeight="1"><path android:fillColor="#00000000" android:pathData="M0,0h1v1h-1z" /></vector>\n'
    for folder in ['drawable', 'drawable-v21']:
        (res / folder / 'launch_background.xml').write_text(launch, encoding='utf-8')
        (res / folder / 'splash_transparent_icon.xml').write_text(transparent, encoding='utf-8')

print('Platform configuration applied.')
