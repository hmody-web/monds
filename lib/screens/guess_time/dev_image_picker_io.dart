import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<Map<String, Object?>?> pickDeveloperImage() async {
  if (Platform.isWindows) {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Filter = 'Images|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All files|*.*'
$dlg.Multiselect = $false
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dlg.FileName }
''';
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-STA', '-Command', script],
    );
    if (result.exitCode != 0) return null;
    final path = (result.stdout ?? '').toString().trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final Uint8List bytes = await file.readAsBytes();
    return <String, Object?>{'path': path, 'bytes': bytes};
  }

  if (Platform.isAndroid || Platform.isIOS) {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return <String, Object?>{'path': picked.path, 'bytes': bytes};
  }

  return null;
}
