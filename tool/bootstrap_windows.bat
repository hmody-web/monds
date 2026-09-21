@echo off
setlocal
where flutter >nul 2>nul || (
  echo Flutter is not available in PATH.
  exit /b 1
)
cd /d "%~dp0\.."
if not exist android flutter create --platforms=android,ios,web --org com.scrptaty --project-name mundas .
python tool\configure_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run -d chrome --web-browser-flag="--disable-web-security"
