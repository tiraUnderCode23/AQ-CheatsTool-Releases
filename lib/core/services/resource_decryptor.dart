import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Service to decrypt and extract encrypted assets (bin.aqx)
/// Handles: attachments, data (JSON), guides
/// All sensitive files are encrypted and extracted to temp at runtime
class ResourceDecryptor {
  static const String _encryptedFileName = 'bin.aqx';
  static const String _decryptionKey = 'AQ///BMW2024SecureKey!@#';

  static bool _isExtracted = false;
  static String? _extractedPath;
  static String? _dataPath;
  static String? _guidesPath;
  static String? _exeDir;
  static final List<String> _logs = [];

  /// Flag to indicate if running in encrypted mode
  static bool _isEncryptedMode = false;

  /// Check if running in encrypted mode (bin.aqx exists)
  static bool get isEncryptedMode => _isEncryptedMode;

  /// Check if resources are already extracted
  static bool get isExtracted => _isExtracted;

  /// Get the path where attachments are extracted
  static String? get extractedPath => _extractedPath;

  /// Get the path where data files are extracted
  static String? get dataExtractedPath => _dataPath;

  /// Get the path where guides are extracted
  static String? get guidesExtractedPath => _guidesPath;

  /// Get extraction logs for debugging
  static List<String> get logs => _logs;

  /// Initialize and extract attachments if needed
  static Future<bool> initialize() async {
    if (_isExtracted && _extractedPath != null) {
      return true;
    }

    _logs.clear();

    try {
      final exePath = Platform.resolvedExecutable;
      _exeDir = p.dirname(exePath);
      _logs.add('EXE Dir: $_exeDir');

      final encryptedFile = File(p.join(_exeDir!, _encryptedFileName));
      _logs.add('Looking for: ${encryptedFile.path}');

      // Check if encrypted file exists
      if (!await encryptedFile.exists()) {
        _logs.add('bin.aqx not found - Development mode');
        // Running in development mode, use normal paths
        _isExtracted = true;
        _isEncryptedMode = false;
        _extractedPath =
            p.join(_exeDir!, 'data', 'flutter_assets', 'assets', 'attachments');

        // Check if dev path exists
        if (!Directory(_extractedPath!).existsSync()) {
          _extractedPath = 'assets/attachments';
        }
        _logs.add('Dev attachments path: $_extractedPath');
        return true;
      }

      _logs.add('bin.aqx found! Size: ${await encryptedFile.length()} bytes');
      _isEncryptedMode = true;

      // Create temp extraction directory for attachments
      final tempDir = Directory(
          p.join(Platform.environment['TEMP'] ?? _exeDir!, 'AQ_Attachments'));

      // Clean old extractions
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);
      _logs.add('Temp dir: ${tempDir.path}');

      // Read and decrypt
      _logs.add('Reading encrypted file...');
      final encryptedBytes = await encryptedFile.readAsBytes();
      _logs.add('Decrypting ${encryptedBytes.length} bytes...');
      final decryptedBytes = _xorDecrypt(encryptedBytes, _decryptionKey);

      // Extract ZIP
      _logs.add('Extracting ZIP archive...');
      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      _logs.add('Archive contains ${archive.length} files');

      int fileCount = 0;
      for (final file in archive) {
        final filePath = p.join(tempDir.path, file.name);

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          fileCount++;
        } else {
          await Directory(filePath).create(recursive: true);
        }
      }
      _logs.add('Extracted $fileCount files');

      _isExtracted = true;
      _extractedPath = tempDir.path;

      // Set paths for subfolders
      final attachmentsDir = Directory(p.join(tempDir.path, 'attachments'));
      final dataDir = Directory(p.join(tempDir.path, 'data'));
      final guidesDir = Directory(p.join(tempDir.path, 'guides'));

      if (await attachmentsDir.exists()) {
        _extractedPath = attachmentsDir.path;
      }
      if (await dataDir.exists()) {
        _dataPath = dataDir.path;
      }
      if (await guidesDir.exists()) {
        _guidesPath = guidesDir.path;
      }

      _logs.add('Extraction complete! Path: $_extractedPath');
      _logs.add('Data path: $_dataPath');
      _logs.add('Guides path: $_guidesPath');

      // List extracted contents
      final contents = await tempDir.list().toList();
      _logs.add(
          'Contents: ${contents.map((e) => p.basename(e.path)).join(", ")}');

      return true;
    } catch (e, stack) {
      _logs.add('ERROR: $e');
      _logs.add('Stack: $stack');
      print('Error extracting attachments: $e');
      // Even if extraction fails, mark as done to allow app to run
      _isExtracted = true;
      _extractedPath = _exeDir ?? '.';
      return true;
    }
  }

  /// XOR decrypt bytes with key
  static Uint8List _xorDecrypt(Uint8List data, String key) {
    final keyBytes = key.codeUnits;
    final result = Uint8List(data.length);

    for (var i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }

    return result;
  }

  /// Get path to attachments folder (from extracted temp or development)
  static String get attachmentsPath {
    // If we extracted from bin.aqx, use that path directly
    if (_extractedPath != null && _extractedPath!.isNotEmpty) {
      return _extractedPath!;
    }

    // Development or fallback paths
    final possiblePaths = [
      p.join(_exeDir ?? '.', 'data', 'flutter_assets', 'assets', 'attachments'),
      p.join(_exeDir ?? '.', 'attachments'),
      'assets/attachments',
    ];

    for (final path in possiblePaths) {
      if (Directory(path).existsSync()) {
        _logs.add('Found dev attachments at: $path');
        return path;
      }
    }

    _logs.add('No attachments folder found!');
    return _extractedPath ?? '.';
  }

  /// Get path to data folder (JSON files)
  static String get dataPath {
    if (_dataPath != null && _dataPath!.isNotEmpty) {
      return _dataPath!;
    }

    // Development paths
    final possiblePaths = [
      p.join(_exeDir ?? '.', 'data', 'flutter_assets', 'assets', 'data'),
      p.join(_exeDir ?? '.', 'data'),
      'assets/data',
    ];

    for (final path in possiblePaths) {
      if (Directory(path).existsSync()) {
        return path;
      }
    }

    return 'assets/data';
  }

  /// Get path to guides folder
  static String get guidesPath {
    if (_guidesPath != null && _guidesPath!.isNotEmpty) {
      return _guidesPath!;
    }

    // Development paths
    final possiblePaths = [
      p.join(_exeDir ?? '.', 'data', 'flutter_assets', 'assets', 'guides'),
      p.join(_exeDir ?? '.', 'guides'),
      'assets/guides',
    ];

    for (final path in possiblePaths) {
      if (Directory(path).existsSync()) {
        return path;
      }
    }

    return 'assets/guides';
  }

  /// Get a specific attachment file path
  static String getAttachmentPath(String filename) {
    return p.join(attachmentsPath, filename);
  }

  /// Get a specific data file path
  static String getDataPath(String filename) {
    return p.join(dataPath, filename);
  }

  /// Get a specific guide file path
  static String getGuidePath(String filename) {
    return p.join(guidesPath, filename);
  }

  /// Load a data file content (JSON, XML, etc.)
  /// In encrypted mode: reads from extracted temp folder
  /// In dev mode: uses rootBundle to load from assets
  static Future<String> loadDataFile(String filename) async {
    _logs.add('loadDataFile: $filename, encrypted=$_isEncryptedMode');

    if (_isEncryptedMode && _dataPath != null) {
      // Read from extracted temp folder
      final filePath = p.join(_dataPath!, filename);
      final file = File(filePath);
      if (await file.exists()) {
        _logs.add('Loading from encrypted path: $filePath');
        return await file.readAsString();
      }
      _logs.add('File not found in encrypted path: $filePath');
    }

    // Development mode or fallback - try multiple paths
    final possiblePaths = [
      p.join(
          _exeDir ?? '.', 'data', 'flutter_assets', 'assets', 'data', filename),
      p.join(_exeDir ?? '.', 'data', filename),
    ];

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists()) {
        _logs.add('Loading from dev path: $path');
        return await file.readAsString();
      }
    }

    // Final fallback - use rootBundle for development
    _logs.add('Loading from rootBundle: assets/data/$filename');
    return await rootBundle.loadString('assets/data/$filename');
  }

  /// Load an attachment file content
  static Future<String> loadAttachmentFile(String filename) async {
    _logs.add('loadAttachmentFile: $filename, encrypted=$_isEncryptedMode');

    if (_isEncryptedMode && _extractedPath != null) {
      final filePath = p.join(_extractedPath!, filename);
      final file = File(filePath);
      if (await file.exists()) {
        _logs.add('Loading attachment from: $filePath');
        return await file.readAsString();
      }
    }

    // Development mode fallback
    final possiblePaths = [
      p.join(_exeDir ?? '.', 'data', 'flutter_assets', 'assets', 'attachments',
          filename),
      p.join(_exeDir ?? '.', 'attachments', filename),
    ];

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }

    return await rootBundle.loadString('assets/attachments/$filename');
  }

  /// Load a guide file content (HTML)
  static Future<String> loadGuideFile(String filename) async {
    if (_isEncryptedMode && _guidesPath != null) {
      final filePath = p.join(_guidesPath!, filename);
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }

    // Development mode fallback
    final possiblePaths = [
      p.join(_exeDir ?? '.', 'data', 'flutter_assets', 'assets', 'guides',
          filename),
      p.join(_exeDir ?? '.', 'guides', filename),
    ];

    for (final path in possiblePaths) {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }

    return await rootBundle.loadString('assets/guides/$filename');
  }

  /// Cleanup extracted files
  static Future<void> cleanup() async {
    // Clean temp extraction directory
    final tempDir = Directory(
        p.join(Platform.environment['TEMP'] ?? '.', 'AQ_Attachments'));

    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
        _logs.add('Cleaned up temp directory');
      } catch (e) {
        print('Error cleaning up: $e');
      }
    }

    _isExtracted = false;
    _isEncryptedMode = false;
    _extractedPath = null;
    _dataPath = null;
    _guidesPath = null;
  }
}
