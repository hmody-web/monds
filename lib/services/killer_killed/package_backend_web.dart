class PackageBackend {
  Future<String?> packagePath(String fileName) async => null;
  Future<int> existingBytes(String fileName) async => 0;
  Future<void> deletePackage(String fileName) async {}
  Future<String?> sha256Of(String fileName) async => null;
  Future<void> download({
    required Uri uri,
    required String fileName,
    required int startByte,
    required void Function(int received, int? total) onProgress,
    required bool Function() shouldPause,
    required bool Function() shouldCancel,
  }) async {
    // Chrome is used only as a UI preview for this project. Native iOS/Android
    // performs the real resumable package download.
    throw UnsupportedError('نزّل الحزمة من نسخة iPhone أو Android. المعاينة على Chrome لا تخزن ملفات اللعبة.');
  }
}
