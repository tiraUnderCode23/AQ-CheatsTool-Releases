import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Temp Files Service - Manages all temporary files in %TEMP%
/// Matches Python behavior of storing temp files outside app directory
class TempFilesService {
  static const String _appFolderName = 'AQ_CheatsTool';
  static String? _tempBasePath;
  static bool _initialized = false;

  /// Initialize temp directory
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Get Windows TEMP directory
      final tempDir = Platform.environment['TEMP'] ??
          Platform.environment['TMP'] ??
          (await getTemporaryDirectory()).path;

      _tempBasePath = path.join(tempDir, _appFolderName);

      // Create our app's temp folder if it doesn't exist
      final dir = Directory(_tempBasePath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      _initialized = true;
      print('TempFilesService: Initialized at $_tempBasePath');
    } catch (e) {
      print('TempFilesService: Failed to initialize: $e');
      // Fallback to app directory
      _tempBasePath = '.';
      _initialized = true;
    }
  }

  /// Get base temp path
  static String get basePath {
    if (!_initialized) {
      // Synchronous fallback
      _tempBasePath =
          path.join(Platform.environment['TEMP'] ?? '.', _appFolderName);
    }
    return _tempBasePath!;
  }

  /// Get path for a specific category of temp files
  static Future<String> getCategoryPath(TempCategory category) async {
    await initialize();

    final categoryPath = path.join(_tempBasePath!, category.folderName);
    final dir = Directory(categoryPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return categoryPath;
  }

  /// Get path for a specific file in category
  static Future<String> getTempFilePath(
      TempCategory category, String fileName) async {
    final categoryPath = await getCategoryPath(category);
    return path.join(categoryPath, fileName);
  }

  /// Write data to temp file
  static Future<File> writeTempFile(
      TempCategory category, String fileName, List<int> data) async {
    final filePath = await getTempFilePath(category, fileName);
    final file = File(filePath);
    await file.writeAsBytes(data);
    return file;
  }

  /// Read temp file
  static Future<List<int>?> readTempFile(
      TempCategory category, String fileName) async {
    final filePath = await getTempFilePath(category, fileName);
    final file = File(filePath);

    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Check if temp file exists
  static Future<bool> tempFileExists(
      TempCategory category, String fileName) async {
    final filePath = await getTempFilePath(category, fileName);
    return await File(filePath).exists();
  }

  /// Delete specific temp file
  static Future<void> deleteTempFile(
      TempCategory category, String fileName) async {
    final filePath = await getTempFilePath(category, fileName);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clean category folder
  static Future<void> cleanCategory(TempCategory category) async {
    final categoryPath = await getCategoryPath(category);
    final dir = Directory(categoryPath);

    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
    }
  }

  /// Clean all temp files (on app exit or reset)
  static Future<void> cleanAll() async {
    await initialize();

    final dir = Directory(_tempBasePath!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create();
    }
  }

  /// Get total size of temp files
  static Future<int> getTotalSize() async {
    await initialize();

    int total = 0;
    final dir = Directory(_tempBasePath!);

    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    }

    return total;
  }

  /// Format size for display
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get list of all temp files with sizes
  static Future<List<TempFileInfo>> listAllFiles() async {
    await initialize();

    final files = <TempFileInfo>[];
    final dir = Directory(_tempBasePath!);

    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          files.add(TempFileInfo(
            path: entity.path,
            name: path.basename(entity.path),
            size: await entity.length(),
            modified: await entity.lastModified(),
          ));
        }
      }
    }

    return files;
  }

  /// Clean old files (older than specified days)
  static Future<int> cleanOldFiles({int olderThanDays = 7}) async {
    await initialize();

    int deletedCount = 0;
    final threshold = DateTime.now().subtract(Duration(days: olderThanDays));
    final dir = Directory(_tempBasePath!);

    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final modified = await entity.lastModified();
          if (modified.isBefore(threshold)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
    }

    return deletedCount;
  }
}

/// Categories for organizing temp files
enum TempCategory {
  cache('cache'),
  downloads('downloads'),
  exports('exports'),
  logs('logs'),
  sessions('sessions'),
  extracted('extracted'),
  attachments('attachments'),
  images('images'),
  coding('coding'),
  mgu('mgu'),
  ssh('ssh');

  final String folderName;
  const TempCategory(this.folderName);
}

/// Info about a temp file
class TempFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modified;

  TempFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });

  String get formattedSize => TempFilesService.formatSize(size);
}
