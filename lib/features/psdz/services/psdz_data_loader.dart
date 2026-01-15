/// PSDZ Data Loader Service
/// Loads and manages PSDZ data files for ECU simulation
///
/// Supports loading:
/// - CAFD (Coding and Feature Data) files
/// - SWFL (Software Flash) files
/// - NCD (Non-volatile Coding Data) files
/// - SVT/SVG configuration files

library psdz_data_loader;

import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// PSDZ File Types
enum PsdzFileType {
  cafd, // Coding and Feature Data
  swfl, // Software Flash
  btld, // Bootloader
  flsh, // Flash container
  ncd, // Non-volatile Coding Data
  fsc, // FreischaltCode (Activation codes)
  svg, // Software Version Group
}

/// PSDZ File Info
class PsdzFile {
  final String fullPath;
  final PsdzFileType type;
  final String sgbmId;
  final String id;
  final int mainVersion;
  final int subVersion;
  final int patchVersion;
  final int size;
  Uint8List? content;

  PsdzFile({
    required this.fullPath,
    required this.type,
    required this.sgbmId,
    required this.id,
    required this.mainVersion,
    required this.subVersion,
    required this.patchVersion,
    required this.size,
    this.content,
  });

  String get filename => path.basename(fullPath);

  String get version =>
      '${mainVersion.toString().padLeft(3, '0')}_'
      '${subVersion.toString().padLeft(3, '0')}_'
      '${patchVersion.toString().padLeft(3, '0')}';

  String get typePrefix {
    switch (type) {
      case PsdzFileType.cafd:
        return 'CAFD';
      case PsdzFileType.swfl:
        return 'SWFL';
      case PsdzFileType.btld:
        return 'BTLD';
      case PsdzFileType.flsh:
        return 'FLSH';
      case PsdzFileType.ncd:
        return 'NCD';
      case PsdzFileType.fsc:
        return 'FSC';
      case PsdzFileType.svg:
        return 'SVG';
    }
  }

  /// Load content from file
  Future<Uint8List?> load() async {
    if (content != null) return content;

    try {
      final file = File(fullPath);
      if (await file.exists()) {
        content = await file.readAsBytes();
        return content;
      }
    } catch (e) {
      debugPrint('Error loading PSDZ file: $e');
    }
    return null;
  }

  @override
  String toString() => 'PsdzFile($sgbmId, $size bytes)';
}

/// ECU PSDZ Data - all files for one ECU
class EcuPsdzData {
  final String ecuName;
  final int diagnosticAddress;
  final List<PsdzFile> cafdFiles = [];
  final List<PsdzFile> swflFiles = [];
  final List<PsdzFile> btldFiles = [];
  final List<PsdzFile> ncdFiles = [];

  EcuPsdzData({required this.ecuName, required this.diagnosticAddress});

  /// Get main CAFD file
  PsdzFile? get mainCafd => cafdFiles.isNotEmpty ? cafdFiles.first : null;

  /// Get main SWFL file
  PsdzFile? get mainSwfl => swflFiles.isNotEmpty ? swflFiles.first : null;

  /// Get all files
  List<PsdzFile> get allFiles => [
    ...cafdFiles,
    ...swflFiles,
    ...btldFiles,
    ...ncdFiles,
  ];

  /// Total size of all files
  int get totalSize => allFiles.fold(0, (sum, f) => sum + f.size);
}

/// PSDZ Data Loader Service
class PsdzDataLoaderService extends ChangeNotifier {
  String _psdzPath = 'C:/Data/psdzdata';

  // Indexed files
  final Map<String, PsdzFile> _fileIndex = {}; // SGBM-ID -> File
  final Map<String, List<PsdzFile>> _ecuFiles = {}; // ECU name -> Files
  final Map<int, EcuPsdzData> _ecuDataByAddress = {}; // Address -> ECU Data

  // State
  bool _isLoading = false;
  bool _isIndexed = false;
  int _totalFiles = 0;
  String _status = 'Not indexed';

  // Getters
  String get psdzPath => _psdzPath;
  bool get isLoading => _isLoading;
  bool get isIndexed => _isIndexed;
  int get totalFiles => _totalFiles;
  String get status => _status;

  Map<String, PsdzFile> get fileIndex => Map.unmodifiable(_fileIndex);

  set psdzPath(String value) {
    if (_psdzPath != value) {
      _psdzPath = value;
      _isIndexed = false;
      notifyListeners();
    }
  }

  /// Index all files in PSDZ data folder
  Future<void> indexFiles() async {
    if (_isLoading) return;

    _isLoading = true;
    _status = 'Indexing...';
    notifyListeners();

    try {
      _fileIndex.clear();
      _ecuFiles.clear();
      _ecuDataByAddress.clear();
      _totalFiles = 0;

      final sweDir = Directory('$_psdzPath/swe');
      if (!await sweDir.exists()) {
        _status = 'SWE folder not found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _scanDirectory(sweDir);

      _isIndexed = true;
      _status = 'Indexed $_totalFiles files';
      debugPrint('PSDZ: Indexed $_totalFiles files from $_psdzPath');
    } catch (e) {
      _status = 'Error: $e';
      debugPrint('PSDZ indexing error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _scanDirectory(Directory dir) async {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final filename = path.basename(entity.path).toUpperCase();

          // Parse PSDZ filename format: TYPE_ID_VER1_VER2_VER3.ext
          final psdzFile = _parsePsdzFilename(entity.path);
          if (psdzFile != null) {
            _fileIndex[psdzFile.sgbmId] = psdzFile;
            _totalFiles++;

            // Index by ECU if identifiable
            final ecuName = _extractEcuName(psdzFile.sgbmId);
            if (ecuName != null) {
              _ecuFiles.putIfAbsent(ecuName, () => []).add(psdzFile);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning $dir: $e');
    }
  }

  /// Parse PSDZ filename to extract info
  PsdzFile? _parsePsdzFilename(String filePath) {
    final filename = path.basenameWithoutExtension(filePath).toUpperCase();
    final parts = filename.split('_');

    if (parts.length < 5) return null;

    PsdzFileType? type;
    switch (parts[0]) {
      case 'CAFD':
        type = PsdzFileType.cafd;
        break;
      case 'SWFL':
        type = PsdzFileType.swfl;
        break;
      case 'BTLD':
        type = PsdzFileType.btld;
        break;
      case 'FLSH':
        type = PsdzFileType.flsh;
        break;
      case 'NCD':
        type = PsdzFileType.ncd;
        break;
      case 'FSC':
        type = PsdzFileType.fsc;
        break;
      default:
        return null;
    }

    try {
      final id = parts[1];
      final v1 = int.tryParse(parts[2]) ?? 0;
      final v2 = int.tryParse(parts[3]) ?? 0;
      final v3 = int.tryParse(parts[4]) ?? 0;

      final file = File(filePath);
      final size = file.existsSync() ? file.lengthSync() : 0;

      return PsdzFile(
        fullPath: filePath,
        type: type,
        sgbmId: filename,
        id: id,
        mainVersion: v1,
        subVersion: v2,
        patchVersion: v3,
        size: size,
      );
    } catch (e) {
      return null;
    }
  }

  /// Extract ECU name from SGBM-ID
  String? _extractEcuName(String sgbmId) {
    // Common ECU identifiers in SGBM-IDs
    final ecuPatterns = {
      'HU_': 'HU_NBT',
      'NBT': 'HU_NBT',
      'MGU': 'HU_MGU',
      'ZGW': 'ZGW',
      'BDC': 'BDC',
      'FEM': 'FEM',
      'FRM': 'FRM',
      'DME': 'DME',
      'DDE': 'DDE',
      'EGS': 'EGS',
      'DSC': 'DSC',
      'ICM': 'ICM',
      'KAFAS': 'KAFAS',
      'FLA': 'FLA',
      'ACSM': 'ACSM',
      'SZL': 'SZL',
      'IHKA': 'IHKA',
      'KOMBI': 'KOMBI',
      'CAS': 'CAS',
      'EPS': 'EPS',
      'TRSVC': 'TRSVC',
      'SAS': 'SAS',
      'PDC': 'PDC',
      'REM': 'REM',
      'TPMS': 'TPMS',
    };

    final upper = sgbmId.toUpperCase();
    for (var entry in ecuPatterns.entries) {
      if (upper.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Find file by SGBM-ID (exact or partial match)
  PsdzFile? findFile(String sgbmId) {
    final upper = sgbmId.toUpperCase();

    // Exact match
    if (_fileIndex.containsKey(upper)) {
      return _fileIndex[upper];
    }

    // Partial match
    for (var entry in _fileIndex.entries) {
      if (entry.key.contains(upper) || upper.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Find files by type and ID
  List<PsdzFile> findFilesByType(PsdzFileType type, {String? id}) {
    return _fileIndex.values.where((f) {
      if (f.type != type) return false;
      if (id != null && !f.id.contains(id.toUpperCase())) return false;
      return true;
    }).toList();
  }

  /// Find all CAFD files for an ECU
  List<PsdzFile> findCafdForEcu(String ecuName) {
    final files = _ecuFiles[ecuName.toUpperCase()] ?? [];
    return files.where((f) => f.type == PsdzFileType.cafd).toList();
  }

  /// Load CAFD data for ECU by address
  Future<Uint8List?> loadCafdForAddress(int address) async {
    // Map address to ECU name
    final ecuName = _getEcuNameByAddress(address);
    if (ecuName == null) return null;

    final cafdFiles = findCafdForEcu(ecuName);
    if (cafdFiles.isEmpty) return null;

    return await cafdFiles.first.load();
  }

  /// Get ECU name by diagnostic address
  String? _getEcuNameByAddress(int address) {
    const addressToEcu = {
      0x10: 'ZGW',
      0x00: 'CAS',
      0x01: 'ACSM',
      0x12: 'DME',
      0x18: 'EGS',
      0x2A: 'DSC',
      0x30: 'EPS',
      0x63: 'HU_NBT',
      0x71: 'SZL',
      0x72: 'FEM',
      0x6C: 'IHKA',
      0x60: 'KOMBI',
    };

    return addressToEcu[address];
  }

  /// Build ECU data from indexed files
  Future<EcuPsdzData?> buildEcuData(String ecuName, int address) async {
    final files = _ecuFiles[ecuName.toUpperCase()];
    if (files == null || files.isEmpty) return null;

    final ecuData = EcuPsdzData(ecuName: ecuName, diagnosticAddress: address);

    for (var file in files) {
      switch (file.type) {
        case PsdzFileType.cafd:
          ecuData.cafdFiles.add(file);
          break;
        case PsdzFileType.swfl:
          ecuData.swflFiles.add(file);
          break;
        case PsdzFileType.btld:
          ecuData.btldFiles.add(file);
          break;
        case PsdzFileType.ncd:
          ecuData.ncdFiles.add(file);
          break;
        default:
          break;
      }
    }

    _ecuDataByAddress[address] = ecuData;
    return ecuData;
  }

  /// Get cached ECU data by address
  EcuPsdzData? getEcuData(int address) => _ecuDataByAddress[address];

  /// Load and inject CAFD into Virtual ECU
  Future<void> injectCafdToEcu(dynamic ecu, String ecuName) async {
    final cafdFiles = findCafdForEcu(ecuName);

    for (var cafd in cafdFiles) {
      final content = await cafd.load();
      if (content != null && content.isNotEmpty) {
        // Inject coding data into ECU DIDs
        // CAFD data goes into 0x1000-0x1FFF range
        if (content.length >= 32) {
          ecu.loadCAFDData(
            0x1000,
            content.sublist(0, 32.clamp(0, content.length)),
          );
        }
        if (content.length >= 64) {
          ecu.loadCAFDData(
            0x1100,
            content.sublist(32, 64.clamp(32, content.length)),
          );
        }
        if (content.length >= 128) {
          ecu.loadCAFDData(
            0x1200,
            content.sublist(64, 128.clamp(64, content.length)),
          );
        }

        debugPrint('Injected CAFD ${cafd.sgbmId} to $ecuName');
        break; // Use first matching CAFD
      }
    }
  }

  /// Get statistics
  Map<String, int> getStatistics() {
    final stats = <String, int>{
      'total': _totalFiles,
      'cafd': 0,
      'swfl': 0,
      'btld': 0,
      'ncd': 0,
      'other': 0,
    };

    for (var file in _fileIndex.values) {
      switch (file.type) {
        case PsdzFileType.cafd:
          stats['cafd'] = stats['cafd']! + 1;
          break;
        case PsdzFileType.swfl:
          stats['swfl'] = stats['swfl']! + 1;
          break;
        case PsdzFileType.btld:
          stats['btld'] = stats['btld']! + 1;
          break;
        case PsdzFileType.ncd:
          stats['ncd'] = stats['ncd']! + 1;
          break;
        default:
          stats['other'] = stats['other']! + 1;
          break;
      }
    }

    return stats;
  }
}

/// SVT-based PSDZ file matcher
/// Matches SGBM-IDs from SVT to actual files in PSDZ data
class SvtPsdzMatcher {
  final PsdzDataLoaderService _loader;

  SvtPsdzMatcher(this._loader);

  /// Match SVT parts to PSDZ files
  Future<Map<String, PsdzFile?>> matchSvtParts(List<String> sgbmIds) async {
    if (!_loader.isIndexed) {
      await _loader.indexFiles();
    }

    final matches = <String, PsdzFile?>{};

    for (var sgbmId in sgbmIds) {
      matches[sgbmId] = _loader.findFile(sgbmId);
    }

    return matches;
  }

  /// Find missing files from SVT
  List<String> findMissingSgbmIds(List<String> sgbmIds) {
    return sgbmIds.where((id) => _loader.findFile(id) == null).toList();
  }

  /// Get match statistics
  Map<String, dynamic> getMatchStats(List<String> sgbmIds) {
    int found = 0;
    int missing = 0;

    for (var id in sgbmIds) {
      if (_loader.findFile(id) != null) {
        found++;
      } else {
        missing++;
      }
    }

    return {
      'total': sgbmIds.length,
      'found': found,
      'missing': missing,
      'matchRate': sgbmIds.isNotEmpty
          ? (found / sgbmIds.length * 100).toStringAsFixed(1)
          : '0',
    };
  }
}
