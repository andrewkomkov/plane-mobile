import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Simple JSON file cache per entity type.
/// Each entity type is stored as a separate JSON file.
class CacheManager {
  static String? _basePath;

  static Future<String> _getBasePath() async {
    if (_basePath != null) return _basePath!;
    final dir = await getApplicationDocumentsDirectory();
    _basePath = '${dir.path}/plane_cache';
    final cacheDir = Directory(_basePath!);
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return _basePath!;
  }

  static String _key(String entityType, String identifier) {
    // Sanitize identifier for filesystem
    final safe = identifier.replaceAll(RegExp(r'[^\w\-.]'), '_');
    return '${entityType}_$safe';
  }

  /// Write data to cache with a timestamp.
  static Future<void> write(
    String entityType,
    String identifier,
    dynamic data,
  ) async {
    try {
      final basePath = await _getBasePath();
      final file = File('$basePath/${_key(entityType, identifier)}.json');
      final envelope = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      };
      await file.writeAsString(jsonEncode(envelope));
    } catch (_) {
      // Silently fail - cache is best-effort
    }
  }

  /// Read cached data. Returns null if not found or expired.
  /// [maxAge] defaults to 1 hour.
  static Future<CachedData?> read(
    String entityType,
    String identifier, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    try {
      final basePath = await _getBasePath();
      final file = File('$basePath/${_key(entityType, identifier)}.json');
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final envelope = jsonDecode(content) as Map<String, dynamic>;
      final timestamp = DateTime.parse(envelope['timestamp'] as String);
      final age = DateTime.now().difference(timestamp);
      return CachedData(
        data: envelope['data'],
        timestamp: timestamp,
        isStale: age > maxAge,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clear all cached data.
  static Future<void> clearAll() async {
    try {
      final basePath = await _getBasePath();
      final dir = Directory(basePath);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        dir.createSync(recursive: true);
      }
    } catch (_) {}
  }

  /// Clear cache for a specific entity type and identifier.
  static Future<void> clear(String entityType, String identifier) async {
    try {
      final basePath = await _getBasePath();
      final file = File('$basePath/${_key(entityType, identifier)}.json');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class CachedData {
  final dynamic data;
  final DateTime timestamp;
  final bool isStale;

  const CachedData({
    required this.data,
    required this.timestamp,
    required this.isStale,
  });
}
