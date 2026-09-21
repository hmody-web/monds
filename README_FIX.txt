Mundas Fix - iOS startup + launcher icon

Replace these files in the project root using the same paths.
Then push to GitHub and rebuild in Codemagic.

Important:
- The launcher icon is now generated for Android, iOS, Web, Windows and macOS from app_icon_1024.png.
- Codemagic now runs platform configuration before building.
- iOS camera permission is added for QR scanning.
- iOS deployment target is forced to 13.0.
- Bundle ID is forced to com.scrptaty.mundas.
- Startup no longer waits for SystemChrome before runApp.
- mobile_scanner is pinned to 7.0.1 so builds do not silently change plugin versions.

For local regeneration:
flutter pub get
dart run flutter_launcher_icons
