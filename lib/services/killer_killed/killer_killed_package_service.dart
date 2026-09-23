import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/killer_killed_config.dart';
import 'package_backend.dart';

enum KillerPackageStatus { checking, notInstalled, downloading, paused, installed, error }

class KillerPackageManifest {
  final String version;
  final String fileName;
  final String downloadUrl;
  final int? sizeBytes;
  final String? sha256;

  const KillerPackageManifest({
    required this.version,
    required this.fileName,
    required this.downloadUrl,
    this.sizeBytes,
    this.sha256,
  });

  factory KillerPackageManifest.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['download_url'] ?? json['url'] ?? '').toString().trim();
    final name = (json['file_name'] ?? json['filename'] ?? 'killer_killed_v1.pack').toString().trim();
    final downloadUrl = rawUrl.isEmpty
        ? '${KillerKilledConfig.packageBaseUrl}/$name'
        : rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
            ? rawUrl
            : '${KillerKilledConfig.packageBaseUrl}/${rawUrl.replaceFirst(RegExp(r'^/+'), '')}';

    return KillerPackageManifest(
      version: (json['version'] ?? '1').toString(),
      fileName: name.isEmpty ? 'killer_killed_v1.pack' : name,
      downloadUrl: downloadUrl,
      sizeBytes: int.tryParse((json['size_bytes'] ?? '').toString()),
      sha256: (json['sha256'] ?? '').toString().trim().isEmpty
          ? null
          : (json['sha256'] ?? '').toString().trim().toLowerCase(),
    );
  }
}

class KillerKilledPackageService extends ChangeNotifier {
  static const _installedVersionKey = 'killer_killed_installed_version_v1';
  final PackageBackend _backend = PackageBackend();

  KillerPackageStatus status = KillerPackageStatus.checking;
  KillerPackageManifest? manifest;
  int downloadedBytes = 0;
  int? totalBytes;
  String? errorMessage;
  bool _pauseRequested = false;
  bool _cancelRequested = false;

  double get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return 0;
    return (downloadedBytes / total).clamp(0, 1);
  }

  Future<void> initialize() async {
    status = KillerPackageStatus.checking;
    errorMessage = null;
    notifyListeners();

    try {
      manifest = await _fetchManifest();
      final prefs = await SharedPreferences.getInstance();
      final installedVersion = prefs.getString(_installedVersionKey);
      final m = manifest!;
      final path = await _backend.packagePath(m.fileName);
      downloadedBytes = await _backend.existingBytes(m.fileName);
      totalBytes = m.sizeBytes;

      if (installedVersion == m.version && path != null) {
        status = KillerPackageStatus.installed;
      } else if (downloadedBytes > 0) {
        status = KillerPackageStatus.paused;
      } else {
        status = KillerPackageStatus.notInstalled;
      }
    } catch (e) {
      manifest = null;
      downloadedBytes = 0;
      totalBytes = null;
      status = KillerPackageStatus.error;
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<KillerPackageManifest> _fetchManifest() async {
    final uri = Uri.parse('${KillerKilledConfig.packageBaseUrl}/manifest.json');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode == 404) {
      throw Exception('ملف manifest.json غير موجود على الخادم: $uri');
    }
    if (response.statusCode != 200) {
      throw Exception('تعذر قراءة manifest.json — HTTP ${response.statusCode}');
    }

    try {
      return KillerPackageManifest.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      throw Exception('ملف manifest.json موجود لكنه غير صالح.');
    }
  }

  Future<void> startOrResume() async {
    if (manifest == null) {
      await initialize();
      if (manifest == null) return;
    }

    final m = manifest!;
    _pauseRequested = false;
    _cancelRequested = false;
    errorMessage = null;
    status = KillerPackageStatus.downloading;
    downloadedBytes = await _backend.existingBytes(m.fileName);
    notifyListeners();

    try {
      await _backend.download(
        uri: Uri.parse(m.downloadUrl),
        fileName: m.fileName,
        startByte: downloadedBytes,
        shouldPause: () => _pauseRequested,
        shouldCancel: () => _cancelRequested,
        onProgress: (received, total) {
          downloadedBytes = received;
          totalBytes = total ?? totalBytes ?? m.sizeBytes;
          notifyListeners();
        },
      );

      if (_cancelRequested) return;
      if (_pauseRequested) {
        status = KillerPackageStatus.paused;
        notifyListeners();
        return;
      }

      if (m.sha256 != null) {
        final actual = await _backend.sha256Of(m.fileName);
        if (actual == null || actual.toLowerCase() != m.sha256) {
          await _backend.deletePackage(m.fileName);
          downloadedBytes = 0;
          throw Exception('فشل التحقق من سلامة ملفات اللعبة (SHA-256).');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_installedVersionKey, m.version);
      status = KillerPackageStatus.installed;
    } catch (e) {
      if (_pauseRequested) {
        status = KillerPackageStatus.paused;
      } else if (_cancelRequested) {
        status = KillerPackageStatus.notInstalled;
      } else {
        status = KillerPackageStatus.error;
        final text = e.toString().replaceFirst('Unsupported operation: ', '').replaceFirst('Exception: ', '');
        errorMessage = text.contains('HTTP 404')
            ? 'ملف الحزمة غير موجود على الخادم: ${m.downloadUrl}'
            : text;
      }
    }
    notifyListeners();
  }

  void pause() {
    if (status != KillerPackageStatus.downloading) return;
    _pauseRequested = true;
  }

  Future<void> cancel() async {
    final m = manifest;
    if (m == null) return;
    _cancelRequested = true;
    _pauseRequested = false;
    await _backend.deletePackage(m.fileName);
    downloadedBytes = 0;
    totalBytes = m.sizeBytes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_installedVersionKey);
    status = KillerPackageStatus.notInstalled;
    notifyListeners();
  }
}
