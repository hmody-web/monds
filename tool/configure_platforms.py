from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
BUNDLE_ID = "com.scrptaty.mundas"
APP_NAME = "مندس"
IOS_TARGET = "13.0"


def replace_or_insert_plist_key(text: str, key: str, value: str) -> str:
    pattern = rf"<key>{re.escape(key)}</key>\s*<string>.*?</string>"
    replacement = f"<key>{key}</key>\n\t<string>{value}</string>"
    if re.search(pattern, text, flags=re.S):
        return re.sub(pattern, replacement, text, count=1, flags=re.S)
    return text.replace("</dict>", f"\t{replacement}\n</dict>", 1)


# Android
manifest = root / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    s = manifest.read_text(encoding="utf-8")
    if "android.permission.INTERNET" not in s:
        s = s.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.INTERNET" />',
            1,
        )
    if "android.permission.CAMERA" not in s:
        s = s.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.CAMERA" />',
            1,
        )
    s = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', s, count=1)
    manifest.write_text(s, encoding="utf-8")

# Android Gradle Kotlin DSL / Groovy
for gradle in [root / "android/app/build.gradle.kts", root / "android/app/build.gradle"]:
    if not gradle.exists():
        continue
    s = gradle.read_text(encoding="utf-8")
    s = re.sub(r'(namespace\s*=\s*")[^"]+("")', rf'\1{BUNDLE_ID}\2', s)
    s = re.sub(r'(applicationId\s*=\s*")[^"]+("")', rf'\1{BUNDLE_ID}\2', s)
    s = re.sub(r'(namespace\s+)["\'][^"\']+["\']', rf'\1"{BUNDLE_ID}"', s)
    s = re.sub(r'(applicationId\s+)["\'][^"\']+["\']', rf'\1"{BUNDLE_ID}"', s)
    gradle.write_text(s, encoding="utf-8")

# iOS Info.plist
plist = root / "ios/Runner/Info.plist"
if plist.exists():
    s = plist.read_text(encoding="utf-8")
    s = replace_or_insert_plist_key(s, "CFBundleDisplayName", APP_NAME)
    s = replace_or_insert_plist_key(
        s,
        "NSCameraUsageDescription",
        "يستخدم مندس الكاميرا لمسح رمز QR والانضمام إلى غرفة أصدقائك.",
    )
    plist.write_text(s, encoding="utf-8")

# iOS deployment target in Podfile
podfile = root / "ios/Podfile"
if podfile.exists():
    s = podfile.read_text(encoding="utf-8")
    if re.search(r"^\s*platform\s*:ios", s, flags=re.M):
        s = re.sub(
            r"^\s*#?\s*platform\s*:ios,\s*['\"][^'\"]+['\"]",
            f"platform :ios, '{IOS_TARGET}'",
            s,
            count=1,
            flags=re.M,
        )
    else:
        s = f"platform :ios, '{IOS_TARGET}'\n\n" + s
    podfile.write_text(s, encoding="utf-8")

# iOS bundle id + minimum target in Xcode project
pbx = root / "ios/Runner.xcodeproj/project.pbxproj"
if pbx.exists():
    s = pbx.read_text(encoding="utf-8")
    s = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;", f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};", s)
    s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [^;]+;", f"IPHONEOS_DEPLOYMENT_TARGET = {IOS_TARGET};", s)
    pbx.write_text(s, encoding="utf-8")

print("Platform configuration applied successfully.")
print(f"Bundle ID: {BUNDLE_ID}")
print(f"iOS minimum: {IOS_TARGET}")
