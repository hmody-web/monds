import 'dart:io';
import 'dart:typed_data';

Future<Map<String, Object?>?> pickDeveloperImage() async {
  if (!Platform.isWindows) return null;
  const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Filter = 'Images|*.png;*.jpg;*.jpeg;*.webp;*.bmp|All files|*.*'
$dlg.Multiselect = $false
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $dlg.FileName }
''';
  final result = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
  if (result.exitCode != 0) return null;
  final path = (result.stdout ?? '').toString().trim();
  if (path.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  final Uint8List bytes = await file.readAsBytes();
  return <String, Object?>{'path': path, 'bytes': bytes};
}
