from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    s = manifest.read_text(encoding='utf-8')
    if 'android.permission.INTERNET' not in s:
        s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.CAMERA" />')
    elif 'android.permission.CAMERA' not in s:
        s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.CAMERA" />')
    s = re.sub(r'android:label="[^"]*"', 'android:label="مندس"', s, count=1)
    manifest.write_text(s, encoding='utf-8')

plist = root / 'ios/Runner/Info.plist'
if plist.exists():
    s = plist.read_text(encoding='utf-8')
    s = s.replace('<string>mundas</string>', '<string>مندس</string>')
    if '<key>NSCameraUsageDescription</key>' not in s:
        s = s.replace('</dict>', '\t<key>NSCameraUsageDescription</key>\n\t<string>يستخدم مندس الكاميرا لمسح رمز QR والانضمام إلى غرفة أصدقائك.</string>\n</dict>')
    plist.write_text(s, encoding='utf-8')

print('Platform configuration applied.')
