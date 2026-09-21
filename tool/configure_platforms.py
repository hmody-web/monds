from pathlib import Path
import re
import plistlib

root = Path(__file__).resolve().parents[1]

BUNDLE_ID = "com.scrptaty.mundas"
APP_NAME = "مندس"
IOS_TARGET = "15.0"

# Info.plist
plist_path = root / "ios" / "Runner" / "Info.plist"
if plist_path.exists():
    with plist_path.open("rb") as f:
        plist = plistlib.load(f)

    plist["CFBundleDisplayName"] = APP_NAME
    plist["NSCameraUsageDescription"] = "يستخدم مندس الكاميرا لمسح رمز QR والانضمام إلى غرفة أصدقائك."

    with plist_path.open("wb") as f:
        plistlib.dump(plist, f, sort_keys=False)

# Xcode project: bundle ID + deployment target
pbx = root / "ios" / "Runner.xcodeproj" / "project.pbxproj"
if not pbx.exists():
    raise SystemExit("ERROR: ios/Runner.xcodeproj/project.pbxproj not found")

s = pbx.read_text(encoding="utf-8")

s = re.sub(
    r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
    f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
    s,
)

# Replace every iOS deployment target found in project/targets.
if re.search(r"IPHONEOS_DEPLOYMENT_TARGET = [^;]+;", s):
    s = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET = [^;]+;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {IOS_TARGET};",
        s,
    )

pbx.write_text(s, encoding="utf-8")

# Flutter AppFrameworkInfo minimum OS, when present.
framework_plist = root / "ios" / "Flutter" / "AppFrameworkInfo.plist"
if framework_plist.exists():
    with framework_plist.open("rb") as f:
        framework_info = plistlib.load(f)
    framework_info["MinimumOSVersion"] = IOS_TARGET
    with framework_plist.open("wb") as f:
        plistlib.dump(framework_info, f, sort_keys=False)

print(f"Configured Bundle ID: {BUNDLE_ID}")
print(f"Configured iOS minimum deployment target: {IOS_TARGET}")
