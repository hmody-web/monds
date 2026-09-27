import 'dart:io';

Future<String?> pickDeveloperAudio() async {
  if (!Platform.isWindows) return null;
  const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Filter = 'Audio|*.mp3;*.wav;*.m4a;*.aac;*.ogg;*.flac|All files|*.*'
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
  return path;
}
