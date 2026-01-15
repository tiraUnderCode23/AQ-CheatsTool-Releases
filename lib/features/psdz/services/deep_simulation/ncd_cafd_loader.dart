/// NCD/CAFD Loader - Load and parse BMW coding files
/// Reads NCD files from backup and CAFD files from PSDZ
///
/// NCD Format: Binary coding data from E-Sys read operations
/// CAFD Format: Coding Application Files from PSDZ
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library ncd_cafd_loader;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// NCD File Parser
class NcdFile {
  final String fileName;
  final String sgbmId;
  final String ecuName;
  final Uint8List rawData;
  final Map<int, Uint8List> codingBlocks;
  final Map<String, dynamic> metadata;

  NcdFile({
    required this.fileName,
    required this.sgbmId,
    required this.ecuName,
    required this.rawData,
    this.codingBlocks = const {},
    this.metadata = const {},
  });

  /// Get coding data for a specific DID
  Uint8List? getCodingData(int did) {
    return codingBlocks[did];
  }

  /// Get full coding binary
  Uint8List get fullCodingData => rawData;
}

/// CAFD File Parser
class CafdFile {
  final String fileName;
  final String sgbmId;
  final String version;
  final Uint8List rawData;
  final List<CafdCodingArea> codingAreas;
  final Map<String, dynamic> header;

  CafdFile({
    required this.fileName,
    required this.sgbmId,
    required this.version,
    required this.rawData,
    this.codingAreas = const [],
    this.header = const {},
  });

  /// Get coding area by name
  CafdCodingArea? getCodingArea(String name) {
    return codingAreas.where((a) => a.name == name).firstOrNull;
  }
}

/// CAFD Coding Area
class CafdCodingArea {
  final String name;
  final int offset;
  final int length;
  final Uint8List data;
  final Map<String, CafdCodingField> fields;

  CafdCodingArea({
    required this.name,
    required this.offset,
    required this.length,
    required this.data,
    this.fields = const {},
  });
}

/// CAFD Coding Field
class CafdCodingField {
  final String name;
  final int bitOffset;
  final int bitLength;
  final dynamic value;
  final String? unit;

  CafdCodingField({
    required this.name,
    required this.bitOffset,
    required this.bitLength,
    this.value,
    this.unit,
  });
}

/// NCD/CAFD Loader Service
class NcdCafdLoader extends ChangeNotifier {
  // Cached files
  final Map<String, NcdFile> _ncdFiles = {};
  final Map<String, CafdFile> _cafdFiles = {};

  // Paths
  String _backupPath = 'C:/Data/Backup';
  String _psdzPath = 'C:/Data/psdzdata';

  // State
  bool _isLoading = false;
  String _statusMessage = 'Ready';
  int _loadedNcdCount = 0;
  int _loadedCafdCount = 0;

  // Getters
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  int get loadedNcdCount => _loadedNcdCount;
  int get loadedCafdCount => _loadedCafdCount;
  List<NcdFile> get allNcdFiles => _ncdFiles.values.toList();
  List<CafdFile> get allCafdFiles => _cafdFiles.values.toList();

  /// Set backup path
  set backupPath(String path) {
    _backupPath = path;
    notifyListeners();
  }

  /// Set PSDZ path
  set psdzPath(String path) {
    _psdzPath = path;
    notifyListeners();
  }

  /// Load NCD file from backup
  Future<NcdFile?> loadNcdFile(File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;

      // Extract SGBM ID and ECU name from filename
      // Format: ECU_CAFD_xxxxxxxx_xxx_xxx_xxx.ncd
      final match = RegExp(
        r'([A-Z0-9_]+)_([A-Z]+)_([0-9a-f]+)_(\d+)_(\d+)_(\d+)\.ncd',
        caseSensitive: false,
      ).firstMatch(fileName);

      String ecuName = 'UNKNOWN';
      String sgbmId = fileName;

      if (match != null) {
        ecuName = match.group(1) ?? 'UNKNOWN';
        final type = match.group(2) ?? 'CAFD';
        final id = match.group(3) ?? '00000000';
        final v1 = match.group(4) ?? '000';
        final v2 = match.group(5) ?? '000';
        final v3 = match.group(6) ?? '000';
        sgbmId = '${type}_${id}_${v1}_${v2}_$v3';
      }

      // Read raw data
      final rawData = await file.readAsBytes();

      // Parse coding blocks
      final codingBlocks = _parseNcdCodingBlocks(rawData);

      final ncdFile = NcdFile(
        fileName: fileName,
        sgbmId: sgbmId,
        ecuName: ecuName,
        rawData: Uint8List.fromList(rawData),
        codingBlocks: codingBlocks,
        metadata: {
          'fileSize': rawData.length,
          'loadTime': DateTime.now().toIso8601String(),
        },
      );

      _ncdFiles[sgbmId] = ncdFile;
      _loadedNcdCount++;
      notifyListeners();

      return ncdFile;
    } catch (e) {
      debugPrint('Error loading NCD file: $e');
      return null;
    }
  }

  /// Parse NCD coding blocks
  Map<int, Uint8List> _parseNcdCodingBlocks(List<int> data) {
    final blocks = <int, Uint8List>{};

    if (data.length < 4) return blocks;

    // NCD format (simplified):
    // - First 2 bytes: Total length
    // - Following blocks: DID (2 bytes) + Length (1 byte) + Data

    int offset = 0;

    // Skip header if present
    if (data.length > 4 && data[0] == 0x00 && data[1] == 0x00) {
      offset = 4;
    }

    // Store as single coding block at DID 0x1000
    final codingData = data.length > 256
        ? data.sublist(offset, offset + 256)
        : data.sublist(offset);
    blocks[0x1000] = Uint8List.fromList(codingData);

    // Also try to parse structured blocks
    try {
      int pos = offset;
      while (pos < data.length - 3) {
        final did = (data[pos] << 8) | data[pos + 1];
        final length = data[pos + 2];

        if (length > 0 && pos + 3 + length <= data.length) {
          blocks[did] = Uint8List.fromList(
            data.sublist(pos + 3, pos + 3 + length),
          );
          pos += 3 + length;
        } else {
          break;
        }
      }
    } catch (e) {
      // Parsing failed, use simple block
    }

    return blocks;
  }

  /// Load CAFD file from PSDZ
  Future<CafdFile?> loadCafdFile(File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;

      // Extract SGBM ID and version from filename
      // Format: cafd_xxxxxxxx.caf.xxx_xxx_xxx
      final match = RegExp(
        r'cafd_([0-9a-f]+)\.caf\.(\d+)_(\d+)_(\d+)',
        caseSensitive: false,
      ).firstMatch(fileName);

      String sgbmId = 'CAFD_00000000';
      String version = '000_000_000';

      if (match != null) {
        sgbmId = 'CAFD_${match.group(1)}';
        version = '${match.group(2)}_${match.group(3)}_${match.group(4)}';
      }

      // Read raw data
      final rawData = await file.readAsBytes();

      // Parse CAFD structure
      final codingAreas = _parseCafdCodingAreas(rawData);
      final header = _parseCafdHeader(rawData);

      final cafdFile = CafdFile(
        fileName: fileName,
        sgbmId: sgbmId,
        version: version,
        rawData: Uint8List.fromList(rawData),
        codingAreas: codingAreas,
        header: header,
      );

      _cafdFiles['${sgbmId}_$version'] = cafdFile;
      _loadedCafdCount++;
      notifyListeners();

      return cafdFile;
    } catch (e) {
      debugPrint('Error loading CAFD file: $e');
      return null;
    }
  }

  /// Parse CAFD header
  Map<String, dynamic> _parseCafdHeader(List<int> data) {
    if (data.length < 16) return {};

    return {
      'signature': data.sublist(0, 4),
      'version': data[4],
      'length': (data[8] << 24) | (data[9] << 16) | (data[10] << 8) | data[11],
    };
  }

  /// Parse CAFD coding areas
  List<CafdCodingArea> _parseCafdCodingAreas(List<int> data) {
    final areas = <CafdCodingArea>[];

    if (data.length < 32) return areas;

    // CAFD files are binary with structured coding data
    // For simulation, we create a single coding area with the full data

    final codingData = data.length > 256 ? data.sublist(0, 256) : data;

    areas.add(
      CafdCodingArea(
        name: 'MAIN_CODING',
        offset: 0,
        length: codingData.length,
        data: Uint8List.fromList(codingData),
      ),
    );

    return areas;
  }

  /// Load all NCD files for an ECU from backup folder
  Future<List<NcdFile>> loadEcuNcdFiles(String ecuPath) async {
    final loaded = <NcdFile>[];

    try {
      final dir = Directory(ecuPath);
      if (!await dir.exists()) return loaded;

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.ncd')) {
          final ncd = await loadNcdFile(entity);
          if (ncd != null) {
            loaded.add(ncd);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading ECU NCD files: $e');
    }

    return loaded;
  }

  /// Load all CAFD files matching ECU type
  Future<List<CafdFile>> loadEcuCafdFiles(String ecuType) async {
    final loaded = <CafdFile>[];

    try {
      final cafdDir = Directory('$_psdzPath/swe/cafd');
      if (!await cafdDir.exists()) return loaded;

      // Search for matching CAFD files
      await for (final entity in cafdDir.list()) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          if (fileName.toLowerCase().startsWith('cafd_')) {
            final cafd = await loadCafdFile(entity);
            if (cafd != null) {
              loaded.add(cafd);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading CAFD files: $e');
    }

    return loaded;
  }

  /// Get NCD file by SGBM ID
  NcdFile? getNcdFile(String sgbmId) => _ncdFiles[sgbmId];

  /// Get CAFD file by SGBM ID and version
  CafdFile? getCafdFile(String sgbmId, String version) {
    return _cafdFiles['${sgbmId}_$version'];
  }

  /// Get all NCD files for ECU
  List<NcdFile> getNcdFilesForEcu(String ecuName) {
    return _ncdFiles.values
        .where((f) => f.ecuName.toUpperCase() == ecuName.toUpperCase())
        .toList();
  }

  /// Clear loaded files
  void clear() {
    _ncdFiles.clear();
    _cafdFiles.clear();
    _loadedNcdCount = 0;
    _loadedCafdCount = 0;
    notifyListeners();
  }

  /// Build coding data for ECU from loaded files
  Uint8List buildEcuCodingData(String ecuName, {int maxSize = 256}) {
    final ncdFiles = getNcdFilesForEcu(ecuName);

    if (ncdFiles.isEmpty) {
      // Return empty coding data
      return Uint8List(maxSize);
    }

    // Use the first/latest NCD file
    final ncd = ncdFiles.first;

    if (ncd.rawData.length >= maxSize) {
      return Uint8List.fromList(ncd.rawData.sublist(0, maxSize));
    }

    // Pad to full size
    final result = Uint8List(maxSize);
    for (int i = 0; i < ncd.rawData.length; i++) {
      result[i] = ncd.rawData[i];
    }

    return result;
  }
}

/// Combined ECU Coding Data
class EcuCodingData {
  final String ecuName;
  final int diagAddress;
  final List<NcdFile> ncdFiles;
  final List<CafdFile> cafdFiles;
  final Map<int, Uint8List> didData;

  EcuCodingData({
    required this.ecuName,
    required this.diagAddress,
    this.ncdFiles = const [],
    this.cafdFiles = const [],
    this.didData = const {},
  });

  /// Get coding data for DID
  Uint8List? getCodingDid(int did) {
    // First try pre-built DID data
    if (didData.containsKey(did)) {
      return didData[did];
    }

    // Try NCD files
    for (final ncd in ncdFiles) {
      final data = ncd.getCodingData(did);
      if (data != null) return data;
    }

    return null;
  }

  /// Get full coding binary
  Uint8List get fullCodingData {
    if (ncdFiles.isNotEmpty) {
      return ncdFiles.first.fullCodingData;
    }
    if (cafdFiles.isNotEmpty) {
      return cafdFiles.first.rawData;
    }
    return Uint8List(0);
  }

  /// Has valid coding data
  bool get hasCodingData => ncdFiles.isNotEmpty || cafdFiles.isNotEmpty;
}
