import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PackageBackend {
  Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}killer_killed');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String fileName) async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<String?> packagePath(String fileName) async {
    final file = await _file(fileName);
    return await file.exists() ? file.path : null;
  }

  Future<int> existingBytes(String fileName) async {
    final file = await _file(fileName);
    return await file.exists() ? await file.length() : 0;
  }

  Future<void> deletePackage(String fileName) async {
    final file = await _file(fileName);
    if (await file.exists()) await file.delete();
  }

  Future<String?> sha256Of(String fileName) async {
    final file = await _file(fileName);
    if (!await file.exists()) return null;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> download({
    required Uri uri,
    required String fileName,
    required int startByte,
    required void Function(int received, int? total) onProgress,
    required bool Function() shouldPause,
    required bool Function() shouldCancel,
  }) async {
    final file = await _file(fileName);
    final request = http.Request('GET', uri);
    if (startByte > 0) request.headers['Range'] = 'bytes=$startByte-';

    final response = await http.Client().send(request);
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('HTTP ${response.statusCode}');
    }

    // Some servers ignore Range. Restart safely in that case.
    final resumed = response.statusCode == 206 && startByte > 0;
    final sink = file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = resumed ? startByte : 0;
    final contentLength = response.contentLength;
    final total = contentLength == null ? null : received + contentLength;

    try {
      await for (final chunk in response.stream) {
        if (shouldCancel()) {
          throw const _DownloadStopped(cancelled: true);
        }
        if (shouldPause()) {
          throw const _DownloadStopped(cancelled: false);
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }
}

class _DownloadStopped implements Exception {
  final bool cancelled;
  const _DownloadStopped({required this.cancelled});
}
