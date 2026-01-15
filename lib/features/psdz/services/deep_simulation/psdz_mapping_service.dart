/// PSDZ Mapping Service - Deep ECU Mapping from PSDZ Data
/// Reads mapping files from C:\Data\psdzdata\mapping
/// Provides CAFD/SWFL/BTLD file associations for each ECU
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library psdz_mapping_service;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

/// PSDZ ECU Mapping Entry
class PsdzEcuMapping {
  final String ecuName;
  final String variant;
  final String sgbmType; // CAFD, SWFL, BTLD, HWEL, TYPNR, ZB
  final String sgbmId;
  final String version;
  final File? dataFile;
  final Map<String, String> attributes;

  PsdzEcuMapping({
    required this.ecuName,
    required this.variant,
    required this.sgbmType,
    required this.sgbmId,
    required this.version,
    this.dataFile,
    this.attributes = const {},
  });

  String get fullSgbmId => '${sgbmType}_${sgbmId}_$version';

  @override
  String toString() => '$ecuName ($variant) - $sgbmType: $sgbmId v$version';
}

/// PSDZ ECU Definition with all software components
class PsdzEcuDefinition {
  final String name;
  final String variant;
  final int diagAddress;
  final List<PsdzEcuMapping> cafdMappings;
  final List<PsdzEcuMapping> swflMappings;
  final List<PsdzEcuMapping> btldMappings;
  final List<PsdzEcuMapping> hwelMappings;
  final List<PsdzEcuMapping> typnrMappings;
  final List<PsdzEcuMapping> zbMappings;
  final Map<int, Uint8List> defaultDids;

  PsdzEcuDefinition({
    required this.name,
    required this.variant,
    this.diagAddress = 0,
    this.cafdMappings = const [],
    this.swflMappings = const [],
    this.btldMappings = const [],
    this.hwelMappings = const [],
    this.typnrMappings = const [],
    this.zbMappings = const [],
    this.defaultDids = const {},
  });

  List<PsdzEcuMapping> get allMappings => [
    ...cafdMappings,
    ...swflMappings,
    ...btldMappings,
    ...hwelMappings,
    ...typnrMappings,
    ...zbMappings,
  ];

  /// Get the latest CAFD file
  PsdzEcuMapping? get latestCafd {
    if (cafdMappings.isEmpty) return null;
    return cafdMappings.reduce(
      (a, b) => _compareVersions(a.version, b.version) >= 0 ? a : b,
    );
  }

  /// Get the latest BTLD file
  PsdzEcuMapping? get latestBtld {
    if (btldMappings.isEmpty) return null;
    return btldMappings.reduce(
      (a, b) => _compareVersions(a.version, b.version) >= 0 ? a : b,
    );
  }

  /// Get the latest SWFL file
  PsdzEcuMapping? get latestSwfl {
    if (swflMappings.isEmpty) return null;
    return swflMappings.reduce(
      (a, b) => _compareVersions(a.version, b.version) >= 0 ? a : b,
    );
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('_').map((s) => int.tryParse(s) ?? 0).toList();
    final bParts = b.split('_').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal != bVal) return aVal - bVal;
    }
    return 0;
  }
}

/// PSDZ Mapping Service
class PsdzMappingService extends ChangeNotifier {
  // Paths
  String _psdzBasePath = 'C:/Data/psdzdata';
  String get mappingPath => '$_psdzBasePath/mapping';
  String get swePath => '$_psdzBasePath/swe';
  String get cafdPath => '$swePath/cafd';
  String get swflPath => '$swePath/swfl';
  String get btldPath => '$swePath/btld';

  // Indexed data
  final Map<String, PsdzEcuDefinition> _ecuDefinitions = {};
  final Map<String, List<PsdzEcuMapping>> _mappingsByType = {};
  final Map<String, File> _cafdFiles = {};
  final Map<String, File> _swflFiles = {};
  final Map<String, File> _btldFiles = {};

  // State
  bool _isLoading = false;
  bool _isLoaded = false;
  String _statusMessage = 'Not loaded';
  int _totalMappings = 0;
  int _totalCafdFiles = 0;
  int _totalSwflFiles = 0;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String get statusMessage => _statusMessage;
  int get totalMappings => _totalMappings;
  int get totalCafdFiles => _totalCafdFiles;
  int get totalSwflFiles => _totalSwflFiles;
  List<PsdzEcuDefinition> get ecuDefinitions => _ecuDefinitions.values.toList();

  /// Get PSDZ base path
  String get psdzBasePath => _psdzBasePath;

  /// Set PSDZ base path
  set psdzBasePath(String path) {
    _psdzBasePath = path;
    notifyListeners();
  }

  /// Index all PSDZ mapping files
  Future<void> indexMappings() async {
    _isLoading = true;
    _statusMessage = 'Indexing PSDZ mappings...';
    notifyListeners();

    try {
      // Clear previous data
      _ecuDefinitions.clear();
      _mappingsByType.clear();
      _cafdFiles.clear();
      _swflFiles.clear();
      _btldFiles.clear();

      // Index mapping XML files
      await _indexMappingDirectory();

      // Index CAFD files
      await _indexCafdFiles();

      // Index SWFL files
      await _indexSwflFiles();

      // Index BTLD files
      await _indexBtldFiles();

      // Link mappings to data files
      _linkMappingsToFiles();

      _isLoaded = true;
      _statusMessage =
          'Indexed $_totalMappings mappings, '
          '$_totalCafdFiles CAFD, $_totalSwflFiles SWFL files';

      debugPrint('PSDZ Mapping: $_statusMessage');
    } catch (e) {
      _statusMessage = 'Index error: $e';
      debugPrint('PSDZ Mapping Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Index mapping XML files
  Future<void> _indexMappingDirectory() async {
    final mappingDir = Directory(mappingPath);
    if (!await mappingDir.exists()) {
      debugPrint('Mapping directory not found: $mappingPath');
      return;
    }

    final files = await mappingDir
        .list()
        .where((f) => f is File && f.path.endsWith('.xml'))
        .cast<File>()
        .toList();

    debugPrint('Found ${files.length} mapping XML files');

    for (final file in files) {
      try {
        await _parseMappingFile(file);
      } catch (e) {
        debugPrint('Error parsing ${file.path}: $e');
      }
    }
  }

  /// Parse a single mapping XML file
  Future<void> _parseMappingFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    // Parse filename: ECU__VARIANT_TYPE.xml
    // Example: AMP__HIFI01_CAFD.xml
    final nameMatch = RegExp(
      r'^([A-Z0-9]+)__([A-Z0-9]+)_([A-Z]+)\.xml$',
    ).firstMatch(fileName);

    if (nameMatch == null) return;

    final ecuName = nameMatch.group(1)!;
    final variant = nameMatch.group(2)!;
    final sgbmType = nameMatch.group(3)!;

    try {
      final content = await file.readAsString();
      final document = XmlDocument.parse(content);

      // Parse mappings from XML
      final mappings = _parseXmlMappings(document, ecuName, variant, sgbmType);

      // Store mappings
      final key = '$ecuName/$variant';
      if (!_ecuDefinitions.containsKey(key)) {
        _ecuDefinitions[key] = PsdzEcuDefinition(
          name: ecuName,
          variant: variant,
          cafdMappings: [],
          swflMappings: [],
          btldMappings: [],
          hwelMappings: [],
          typnrMappings: [],
          zbMappings: [],
        );
      }

      // Add mappings by type
      final definition = _ecuDefinitions[key]!;
      for (final mapping in mappings) {
        switch (sgbmType) {
          case 'CAFD':
            definition.cafdMappings.add(mapping);
            break;
          case 'SWFL':
            definition.swflMappings.add(mapping);
            break;
          case 'BTLD':
            definition.btldMappings.add(mapping);
            break;
          case 'HWEL':
            definition.hwelMappings.add(mapping);
            break;
          case 'TYPNR':
            definition.typnrMappings.add(mapping);
            break;
          case 'ZB':
            definition.zbMappings.add(mapping);
            break;
        }
        _totalMappings++;
      }

      // Store in type index
      _mappingsByType.putIfAbsent(sgbmType, () => []).addAll(mappings);
    } catch (e) {
      debugPrint('XML parse error for $fileName: $e');
    }
  }

  /// Parse XML document for mappings
  List<PsdzEcuMapping> _parseXmlMappings(
    XmlDocument document,
    String ecuName,
    String variant,
    String sgbmType,
  ) {
    final mappings = <PsdzEcuMapping>[];

    // Find all SGBM elements
    final sgbmElements = document.findAllElements('SGBM');

    for (final element in sgbmElements) {
      final id =
          element.getAttribute('ID') ??
          element.findElements('ID').firstOrNull?.innerText ??
          '';
      final version =
          element.getAttribute('VERSION') ??
          element.findElements('VERSION').firstOrNull?.innerText ??
          '001_000_000';

      if (id.isNotEmpty) {
        final attributes = <String, String>{};
        for (final attr in element.attributes) {
          attributes[attr.name.local] = attr.value;
        }

        mappings.add(
          PsdzEcuMapping(
            ecuName: ecuName,
            variant: variant,
            sgbmType: sgbmType,
            sgbmId: id,
            version: version,
            attributes: attributes,
          ),
        );
      }
    }

    // Also check for direct references
    final refs = document.findAllElements('REF');
    for (final ref in refs) {
      final id = ref.getAttribute('SGBM_ID') ?? ref.innerText;
      final version = ref.getAttribute('VERSION') ?? '001_000_000';

      if (id.isNotEmpty) {
        mappings.add(
          PsdzEcuMapping(
            ecuName: ecuName,
            variant: variant,
            sgbmType: sgbmType,
            sgbmId: id,
            version: version,
          ),
        );
      }
    }

    return mappings;
  }

  /// Index CAFD files
  Future<void> _indexCafdFiles() async {
    final cafdDir = Directory(cafdPath);
    if (!await cafdDir.exists()) return;

    await for (final entity in cafdDir.list()) {
      if (entity is File && entity.path.contains('cafd_')) {
        final name = entity.path.split(Platform.pathSeparator).last;
        _cafdFiles[name] = entity;
        _totalCafdFiles++;
      }
    }

    debugPrint('Indexed $_totalCafdFiles CAFD files');
  }

  /// Index SWFL files
  Future<void> _indexSwflFiles() async {
    final swflDir = Directory(swflPath);
    if (!await swflDir.exists()) return;

    await for (final entity in swflDir.list()) {
      if (entity is File && entity.path.contains('swfl_')) {
        final name = entity.path.split(Platform.pathSeparator).last;
        _swflFiles[name] = entity;
        _totalSwflFiles++;
      }
    }

    debugPrint('Indexed $_totalSwflFiles SWFL files');
  }

  /// Index BTLD files
  Future<void> _indexBtldFiles() async {
    final btldDir = Directory(btldPath);
    if (!await btldDir.exists()) return;

    await for (final entity in btldDir.list()) {
      if (entity is File && entity.path.contains('btld_')) {
        final name = entity.path.split(Platform.pathSeparator).last;
        _btldFiles[name] = entity;
      }
    }
  }

  /// Link mappings to actual data files
  void _linkMappingsToFiles() {
    for (final definition in _ecuDefinitions.values) {
      for (final mapping in definition.cafdMappings) {
        // Try to find matching CAFD file
        final searchPattern = 'cafd_${mapping.sgbmId.toLowerCase()}';
        for (final entry in _cafdFiles.entries) {
          if (entry.key.toLowerCase().contains(searchPattern)) {
            // Found matching file - update mapping
            final index = definition.cafdMappings.indexOf(mapping);
            if (index >= 0) {
              final updated = PsdzEcuMapping(
                ecuName: mapping.ecuName,
                variant: mapping.variant,
                sgbmType: mapping.sgbmType,
                sgbmId: mapping.sgbmId,
                version: mapping.version,
                dataFile: entry.value,
                attributes: mapping.attributes,
              );
              definition.cafdMappings[index] = updated;
            }
            break;
          }
        }
      }
    }
  }

  /// Find ECU definition by name and variant
  PsdzEcuDefinition? findEcu(String ecuName, {String? variant}) {
    if (variant != null) {
      return _ecuDefinitions['$ecuName/$variant'];
    }

    // Return first matching ECU
    return _ecuDefinitions.entries
        .where((e) => e.key.startsWith('$ecuName/'))
        .map((e) => e.value)
        .firstOrNull;
  }

  /// Find all ECUs with CAFD mappings
  List<PsdzEcuDefinition> findEcusWithCafd() {
    return _ecuDefinitions.values
        .where((e) => e.cafdMappings.isNotEmpty)
        .toList();
  }

  /// Get CAFD file by SGBM ID
  File? getCafdFile(String sgbmId) {
    final searchId = sgbmId.toLowerCase();
    for (final entry in _cafdFiles.entries) {
      if (entry.key.toLowerCase().contains(searchId)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Get SWFL file by SGBM ID
  File? getSwflFile(String sgbmId) {
    final searchId = sgbmId.toLowerCase();
    for (final entry in _swflFiles.entries) {
      if (entry.key.toLowerCase().contains(searchId)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Get all ECU names
  List<String> get allEcuNames {
    final names = <String>{};
    for (final key in _ecuDefinitions.keys) {
      names.add(key.split('/').first);
    }
    return names.toList()..sort();
  }

  /// Get variants for ECU
  List<String> getVariantsForEcu(String ecuName) {
    return _ecuDefinitions.entries
        .where((e) => e.key.startsWith('$ecuName/'))
        .map((e) => e.key.split('/').last)
        .toList();
  }

  /// Load CAFD data for ECU
  Future<Uint8List?> loadCafdData(String ecuName, String variant) async {
    final definition = findEcu(ecuName, variant: variant);
    if (definition == null) return null;

    final cafd = definition.latestCafd;
    if (cafd?.dataFile == null) return null;

    try {
      return await cafd!.dataFile!.readAsBytes();
    } catch (e) {
      debugPrint('Error loading CAFD: $e');
      return null;
    }
  }
}
