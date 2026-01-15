import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/ecu.dart';
import '../models/istep.dart';
import '../models/tal_file.dart';

/// PSDZ Service - Manages PSDZ data operations with auto-scan and VIN matching
class PSDZService extends ChangeNotifier {
  // Configuration
  String _psdzPath = 'C:/Data/psdzdata';
  String _outputPath = '';
  String _scanPaths = 'C:/Data/TAL, C:/Data/SVT';
  String _autoScanPath = 'C:/data';
  String _psdzVersion = '';
  String _psdzSize = 'Calculating...';

  // Data
  List<VehicleSeries> _series = [];
  List<IStep> _iSteps = [];
  List<ECU> _ecus = [];
  List<ECUFile> _files = [];
  Map<String, List<String>> _fileIndex = {};

  // Current selection
  String? _selectedSeries;
  String? _selectedIStep;
  String? _selectedECU;

  // TAL/SVT data
  TALFile? _currentTALFile;
  List<LibraryScanResult> _libraryFiles = [];

  // Auto-scan data (C:/data)
  List<VehicleFile> _faFiles = [];
  List<VehicleFile> _svtFiles = [];
  List<VehicleFile> _talFilesScanned = [];
  List<MatchedVehicle> _matchedVehicles = [];
  MatchedVehicle? _selectedVehicle;

  // State
  bool _isLoading = false;
  String _statusMessage = 'Ready';
  double _progress = 0;
  String? _lastScanTime;

  // Getters
  String get psdzPath => _psdzPath;
  String get scanPaths => _scanPaths;
  String get autoScanPath => _autoScanPath;
  String get psdzVersion => _psdzVersion;
  String get psdzSize => _psdzSize;
  List<VehicleSeries> get series => _series;
  List<VehicleSeries> get seriesList => _series;
  List<IStep> get iSteps => _iSteps;
  List<ECU> get ecus => _ecus;
  List<ECUFile> get files => _files;
  String? get selectedSeries => _selectedSeries;
  String? get selectedIStep => _selectedIStep;
  String? get selectedECU => _selectedECU;
  TALFile? get currentTALFile => _currentTALFile;
  List<LibraryScanResult> get libraryFiles => _libraryFiles;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  String? get lastScanTime => _lastScanTime;
  int get ecuCount => _ecus.length;
  int get fileCount => _fileIndex.length;
  bool get isPathValid => Directory(_psdzPath).existsSync();

  // Auto-scan getters
  List<VehicleFile> get faFiles => _faFiles;
  List<VehicleFile> get svtFiles => _svtFiles;
  List<VehicleFile> get talFilesScanned => _talFilesScanned;
  List<MatchedVehicle> get matchedVehicles => _matchedVehicles;
  MatchedVehicle? get selectedVehicle => _selectedVehicle;

  // Setters
  set psdzPath(String value) {
    _psdzPath = value;
    notifyListeners();
  }

  set outputPath(String value) {
    _outputPath = value;
    notifyListeners();
  }

  set scanPaths(String value) {
    _scanPaths = value;
    notifyListeners();
  }

  set autoScanPath(String value) {
    _autoScanPath = value;
    notifyListeners();
  }

  /// Detect PSDZ version from SDP *.ver file
  Future<void> detectPsdzVersion() async {
    try {
      final psdzDir = Directory(_psdzPath);
      if (!await psdzDir.exists()) {
        _psdzVersion = 'N/A';
        return;
      }

      // Calculate size in background
      _calculatePsdzSize();

      // Look for SDP *.ver files
      await for (var entity in psdzDir.list()) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          // Match SDP *.ver or SDP [Version].ver
          if (fileName.startsWith('SDP') && fileName.endsWith('.ver')) {
            // Extract version
            final versionMatch = RegExp(
              r'SDP\s*([\d.]+)\.ver',
            ).firstMatch(fileName);
            String version = '';
            if (versionMatch != null) {
              version = versionMatch.group(1) ?? '';
            } else {
              version = fileName
                  .replaceAll('SDP', '')
                  .replaceAll('.ver', '')
                  .trim();
            }

            if (version.isNotEmpty) {
              _psdzVersion = 'PSDZDATA $version';
              notifyListeners();
              return;
            }
          }
        }
      }
      _psdzVersion = 'PSDZDATA Unknown';
    } catch (e) {
      _psdzVersion = 'Error';
      debugPrint('Error detecting PSDZ version: $e');
    }
    notifyListeners();
  }

  /// Calculate folder size in isolate to prevent UI freeze
  static Future<int> _calculateFolderSizeIsolate(String path) async {
    int totalBytes = 0;
    final dir = Directory(path);

    if (!await dir.exists()) return 0;

    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalBytes += await entity.length();
          } catch (_) {
            // Skip files that can't be read
          }
        }
      }
    } catch (_) {
      // Handle permission errors
    }

    return totalBytes;
  }

  Future<void> _calculatePsdzSize() async {
    _psdzSize = 'Calculating...';
    notifyListeners();

    try {
      final dir = Directory(_psdzPath);
      if (!await dir.exists()) {
        _psdzSize = '0 GB';
        notifyListeners();
        return;
      }

      // Run in isolate to prevent UI freeze
      final totalBytes = await compute(_calculateFolderSizeIsolate, _psdzPath);

      if (totalBytes == 0) {
        _psdzSize = '0 GB';
      } else if (totalBytes < 1024 * 1024) {
        // Less than 1 MB
        final kb = totalBytes / 1024;
        _psdzSize = '${kb.toStringAsFixed(2)} KB';
      } else if (totalBytes < 1024 * 1024 * 1024) {
        // Less than 1 GB
        final mb = totalBytes / (1024 * 1024);
        _psdzSize = '${mb.toStringAsFixed(2)} MB';
      } else {
        final gb = totalBytes / (1024 * 1024 * 1024);
        _psdzSize = '${gb.toStringAsFixed(2)} GB';
      }
      notifyListeners();
    } catch (e) {
      _psdzSize = 'Error: $e';
      notifyListeners();
    }
  }

  /// Select a matched vehicle
  /// Select a matched vehicle
  void selectVehicle(MatchedVehicle vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Auto-scan C:/data for FA, SVT, TAL files
  Future<void> autoScanDataFolder() async {
    _setLoading(true, 'Auto-scanning $_autoScanPath for vehicle files...');

    try {
      _faFiles.clear();
      _svtFiles.clear();
      _talFilesScanned.clear();
      _matchedVehicles.clear();

      final dataDir = Directory(_autoScanPath);
      if (!await dataDir.exists()) {
        _setStatus('Error: Data folder not found at $_autoScanPath');
        _setLoading(false);
        return;
      }

      // Scan for FA, SVT, TAL folders
      await _scanForFileType('FA');
      await _scanForFileType('SVT');
      await _scanForFileType('TAL');

      // Also scan root folder for XML files
      await _scanFolderForXML(_autoScanPath, false);

      // Match vehicles by VIN (from both filename and content)
      _matchVehiclesByVIN();

      _setStatus(
        'Found ${_faFiles.length} FA, ${_svtFiles.length} SVT, ${_talFilesScanned.length} TAL | ${_matchedVehicles.length} matched vehicles',
      );
      notifyListeners();
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Scan for specific file type folder
  Future<void> _scanForFileType(String type) async {
    final folderPath = '$_autoScanPath/$type';
    final folder = Directory(folderPath);

    if (!await folder.exists()) return;

    await _scanFolderForXML(folderPath, true, forceType: type);
  }

  /// Scan folder for XML files
  Future<void> _scanFolderForXML(
    String path,
    bool recursive, {
    String? forceType,
  }) async {
    final folder = Directory(path);
    if (!await folder.exists()) return;

    try {
      await for (var entity in folder.list(recursive: recursive)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.xml')) {
          final existingPaths = {
            ..._faFiles,
            ..._svtFiles,
            ..._talFilesScanned,
          }.map((f) => f.path).toSet();
          if (existingPaths.contains(entity.path)) continue;

          VehicleFile? vehicleFile;

          if (forceType != null) {
            vehicleFile = await _parseVehicleFile(entity.path, forceType);
          } else {
            vehicleFile = await _detectAndParseVehicleFile(entity.path);
          }

          if (vehicleFile != null) {
            switch (vehicleFile.type) {
              case 'FA':
                _faFiles.add(vehicleFile);
                break;
              case 'SVT':
                _svtFiles.add(vehicleFile);
                break;
              case 'TAL':
                _talFilesScanned.add(vehicleFile);
                break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning $path: $e');
    }
  }

  /// Parse vehicle file and extract info
  Future<VehicleFile?> _parseVehicleFile(String path, String type) async {
    try {
      final file = File(path);
      final filename = path.split(Platform.pathSeparator).last;
      String? vin;
      String? series;
      String? istep;
      int ecuCount = 0;

      // First try to extract VIN from filename (e.g., SVT_SOLL_F015_WBAKS4105E0H44791.xml)
      final filenameUpper = filename.toUpperCase();

      // Pattern: VIN is typically a 17-character alphanumeric at the end before .xml
      final vinRegex = RegExp(r'[WV][A-Z0-9]{16}');
      final vinMatch = vinRegex.firstMatch(filenameUpper);
      if (vinMatch != null) {
        vin = vinMatch.group(0);
      }

      // Extract series from filename (e.g., F015, G020, etc.)
      final seriesRegex = RegExp(r'[FGI]\d{3}');
      final seriesMatch = seriesRegex.firstMatch(filenameUpper);
      if (seriesMatch != null) {
        series = seriesMatch.group(0);
      }

      // Now try to parse the XML content
      try {
        final content = await file.readAsString();

        // Use compute to parse XML in a separate isolate to avoid freezing UI
        final result = await compute(parseVehicleXml, {
          'content': content,
          'type': type,
        });

        if (vin == null) vin = result['vin'];
        if (series == null) series = result['series'];
        istep = result['istep'];
        ecuCount = result['ecuCount'] ?? 0;
      } catch (parseError) {
        debugPrint('Error parsing XML content: $parseError');
      }

      return VehicleFile(
        path: path,
        filename: filename,
        type: type,
        vin: vin,
        series: series,
        istep: istep,
        ecuCount: ecuCount,
        lastModified: await file.lastModified(),
      );
    } catch (e) {
      debugPrint('Error parsing $path: $e');
      return null;
    }
  }

  /// Auto-detect file type and parse
  Future<VehicleFile?> _detectAndParseVehicleFile(String path) async {
    try {
      final file = File(path);
      final filename = path.split(Platform.pathSeparator).last.toUpperCase();
      String type = 'UNKNOWN';

      if (filename.contains('FA') || filename.contains('VO')) {
        type = 'FA';
      } else if (filename.contains('SVT') || filename.contains('SVK')) {
        type = 'SVT';
      } else if (filename.contains('TAL')) {
        type = 'TAL';
      } else {
        // Peek content
        final content = await file.readAsString();
        if (content.contains('<FA') || content.contains('<fa')) {
          type = 'FA';
        } else if (content.contains('<SVT') || content.contains('<svt')) {
          type = 'SVT';
        } else if (content.contains('<TAL') || content.contains('<tal')) {
          type = 'TAL';
        }
      }

      if (type != 'UNKNOWN') {
        return _parseVehicleFile(path, type);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Match vehicles by VIN
  void _matchVehiclesByVIN() {
    _matchedVehicles.clear();

    final vinMap = <String, MatchedVehicle>{};

    // Process FA files
    for (var fa in _faFiles) {
      if (fa.vin != null && fa.vin!.isNotEmpty) {
        vinMap.putIfAbsent(
          fa.vin!,
          () =>
              MatchedVehicle(vin: fa.vin!, series: fa.series, istep: fa.istep),
        );
        vinMap[fa.vin!] = MatchedVehicle(
          vin: fa.vin!,
          faFile: fa,
          svtFile: vinMap[fa.vin!]?.svtFile,
          talFiles: vinMap[fa.vin!]?.talFiles ?? [],
          series: fa.series ?? vinMap[fa.vin!]?.series,
          istep: fa.istep ?? vinMap[fa.vin!]?.istep,
        );
      }
    }

    // Process SVT files
    for (var svt in _svtFiles) {
      if (svt.vin != null && svt.vin!.isNotEmpty) {
        vinMap.putIfAbsent(
          svt.vin!,
          () => MatchedVehicle(
            vin: svt.vin!,
            series: svt.series,
            istep: svt.istep,
          ),
        );
        vinMap[svt.vin!] = MatchedVehicle(
          vin: svt.vin!,
          faFile: vinMap[svt.vin!]?.faFile,
          svtFile: svt,
          talFiles: vinMap[svt.vin!]?.talFiles ?? [],
          series: svt.series ?? vinMap[svt.vin!]?.series,
          istep: svt.istep ?? vinMap[svt.vin!]?.istep,
        );
      }
    }

    // Process TAL files
    for (var tal in _talFilesScanned) {
      if (tal.vin != null && tal.vin!.isNotEmpty) {
        vinMap.putIfAbsent(
          tal.vin!,
          () => MatchedVehicle(
            vin: tal.vin!,
            series: tal.series,
            istep: tal.istep,
          ),
        );
        final existing = vinMap[tal.vin!]!;
        vinMap[tal.vin!] = MatchedVehicle(
          vin: tal.vin!,
          faFile: existing.faFile,
          svtFile: existing.svtFile,
          talFiles: [...existing.talFiles, tal],
          series: tal.series ?? existing.series,
          istep: tal.istep ?? existing.istep,
        );
      }
    }

    _matchedVehicles = vinMap.values.toList();
    _matchedVehicles.sort((a, b) {
      if (a.isComplete && !b.isComplete) return -1;
      if (!a.isComplete && b.isComplete) return 1;
      return a.vin.compareTo(b.vin);
    });
  }

  /// Select a matched vehicle for simulation
  Future<void> selectMatchedVehicle(MatchedVehicle vehicle) async {
    _selectedVehicle = vehicle;
    _setStatus('Selected vehicle: ${vehicle.vin}');

    if (vehicle.hasSVT) {
      await loadTALFile(vehicle.svtFile!.path);
    } else if (vehicle.hasTAL && vehicle.talFiles.isNotEmpty) {
      await loadTALFile(vehicle.talFiles.first.path);
    }

    notifyListeners();
  }

  /// Initialize and scan PSDZ data
  Future<void> scanPSDZData() async {
    _setLoading(true, 'Scanning PSDZ data...');

    try {
      final mainseriesPath = '$_psdzPath/mainseries';
      final mainseriesDir = Directory(mainseriesPath);

      if (!await mainseriesDir.exists()) {
        _setStatus('Error: Mainseries folder not found at $mainseriesPath');
        _setLoading(false);
        return;
      }

      _series.clear();
      _iSteps.clear();
      _fileIndex.clear();

      final seriesDirs = await mainseriesDir.list().toList();
      int totalISteps = 0;

      for (var i = 0; i < seriesDirs.length; i++) {
        if (seriesDirs[i] is Directory) {
          final seriesDir = seriesDirs[i] as Directory;
          final seriesCode = seriesDir.path.split(Platform.pathSeparator).last;

          final iStepList = <IStep>[];
          final istepDirs = await seriesDir.list().toList();

          for (var istepDir in istepDirs) {
            if (istepDir is Directory) {
              final istepName = istepDir.path
                  .split(Platform.pathSeparator)
                  .last;
              iStepList.add(
                IStep(name: istepName, series: seriesCode, path: istepDir.path),
              );
              totalISteps++;
            }
          }

          if (iStepList.isNotEmpty) {
            _series.add(VehicleSeries(code: seriesCode, iSteps: iStepList));
          }
        }

        _progress = (i + 1) / seriesDirs.length;
        notifyListeners();
      }

      _series.sort((a, b) => a.code.compareTo(b.code));
      await _buildFileIndex();

      _lastScanTime = DateTime.now().toString().substring(0, 19);
      _setStatus('Loaded ${_series.length} series, $totalISteps I-Steps');

      if (_series.isNotEmpty) {
        selectSeries(_series.first.code);
      }
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Build file index for fast lookup - indexes all files in swe folder
  Future<void> _buildFileIndex() async {
    _fileIndex.clear();
    final swePath = '$_psdzPath/swe';
    final sweDir = Directory(swePath);

    if (!await sweDir.exists()) {
      debugPrint('SWE folder not found at $swePath');
      return;
    }

    final folders = [
      'btld',
      'swfl',
      'swfk',
      'cafd',
      'ibad',
      'blup',
      'hwel',
      'fafp',
      'flsl',
      'tlrt',
      'gwtb',
      'flup',
    ];
    int totalFiles = 0;

    for (var folder in folders) {
      final folderPath = '$swePath/$folder';
      final folderDir = Directory(folderPath);

      if (!await folderDir.exists()) continue;

      try {
        await for (var file in folderDir.list()) {
          if (file is File) {
            final filename = file.path
                .split(Platform.pathSeparator)
                .last
                .toLowerCase();
            final parts = filename.split('_');

            if (parts.length >= 2) {
              // Extract file ID (e.g., swfl_00001234 -> 00001234)
              final fileId = parts[1].split('.')[0];
              _fileIndex.putIfAbsent(fileId, () => []).add(file.path);
              totalFiles++;
            }
          }
        }
      } catch (e) {
        debugPrint('Error indexing $folder: $e');
      }
    }

    debugPrint(
      'Indexed $totalFiles files with ${_fileIndex.length} unique IDs',
    );
    _setStatus(
      'Indexed ${_fileIndex.length} unique file IDs ($totalFiles files)',
    );
  }

  /// Select a series
  void selectSeries(String seriesCode) {
    _selectedSeries = seriesCode;
    _selectedIStep = null;
    _selectedECU = null;
    _ecus.clear();
    _files.clear();

    final seriesData = _series.firstWhere(
      (s) => s.code == seriesCode,
      orElse: () => VehicleSeries(code: seriesCode),
    );

    _iSteps = seriesData.iSteps;

    if (_iSteps.isNotEmpty) {
      selectIStep(_iSteps.last.name);
    }

    notifyListeners();
  }

  /// Select an I-Step
  Future<void> selectIStep(String istepName) async {
    _selectedIStep = istepName;
    _selectedECU = null;
    _files.clear();

    await loadECUs(istepName);
    notifyListeners();
  }

  /// Load ECUs for selected I-Step
  Future<void> loadECUs(String istepName) async {
    _setLoading(true, 'Loading ECUs for $istepName...');

    try {
      final istep = _iSteps.firstWhere(
        (i) => i.name == istepName,
        orElse: () => IStep(name: istepName, series: '', path: ''),
      );

      final mappingPath = '${istep.path}/mapping';
      final mappingDir = Directory(mappingPath);

      if (!await mappingDir.exists()) {
        _setStatus('No mapping folder in $istepName');
        _ecus.clear();
        notifyListeners();
        _setLoading(false);
        return;
      }

      final ecuMap = <String, ECU>{};

      await for (var file in mappingDir.list()) {
        if (file is File &&
            file.path.contains('sweseq_') &&
            file.path.endsWith('.xml')) {
          await _parseSweseqFile(file.path, ecuMap);
        }
      }

      _ecus = ecuMap.values.toList();
      _ecus.sort((a, b) => a.name.compareTo(b.name));

      _setStatus('Loaded ${_ecus.length} ECUs from $istepName');
      notifyListeners();
    } catch (e) {
      _setStatus('Error: $e');
      _ecus.clear();
    } finally {
      _setLoading(false);
    }
  }

  /// Parse sweseq XML file - Extract ECU information from SWERBD format
  Future<void> _parseSweseqFile(String path, Map<String, ECU> ecuMap) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final document = XmlDocument.parse(content);

      // Get all ecuDependencies elements
      for (var dep in document.findAllElements('ecuDependencies')) {
        String ecuName = 'Unknown';
        String addr = '0';

        // Try to find ECU info from nested ecu element
        final ecuElem = dep.findElements('ecu').firstOrNull;
        if (ecuElem != null) {
          // Get baseVariantName - it has the 'name' attribute
          final baseVariantName = ecuElem
              .findElements('baseVariantName')
              .firstOrNull;
          if (baseVariantName != null) {
            ecuName =
                baseVariantName.getAttribute('name') ??
                baseVariantName.innerText.trim();
          }

          // Get diagnostic address
          final diagAddress = ecuElem
              .findElements('diagnosticAddress')
              .firstOrNull;
          if (diagAddress != null) {
            addr =
                diagAddress.getAttribute('physicalOffset') ??
                diagAddress.innerText.trim();
          }
        }

        // Fallback to direct attributes
        if (ecuName == 'Unknown') {
          final directBaseVariant = dep
              .findElements('baseVariantName')
              .firstOrNull;
          if (directBaseVariant != null) {
            ecuName =
                directBaseVariant.getAttribute('name') ??
                directBaseVariant.innerText.trim();
          }
        }

        if (ecuName == 'Unknown') {
          ecuName = dep.getAttribute('baseVariant') ?? 'Unknown';
        }

        if (ecuName == 'Unknown' || ecuName.isEmpty) continue;

        if (!ecuMap.containsKey(ecuName)) {
          ecuMap[ecuName] = ECU(
            name: ecuName,
            variant: ecuName,
            address: _parseAddress(addr),
            files: [],
          );
        }

        // Get bootloader ID
        final btldId = dep.getAttribute('bootloader_id');
        if (btldId != null && btldId.isNotEmpty) {
          final existingFiles = List<ECUFile>.from(ecuMap[ecuName]!.files);
          if (!existingFiles.any(
            (f) =>
                f.id.toLowerCase() == btldId.toLowerCase() &&
                f.processClass == 'BTLD',
          )) {
            existingFiles.add(
              ECUFile(
                processClass: 'BTLD',
                id: btldId,
                mainVersion: '000',
                subVersion: '000',
                patchVersion: '000',
              ),
            );
            ecuMap[ecuName] = ecuMap[ecuName]!.copyWith(files: existingFiles);
          }
        }

        // Get file IDs from preconditions and dependors
        final allIds = <String>{};

        for (var precond in dep.findElements('preconditions')) {
          for (var idElem in precond.findElements('id')) {
            final idText = idElem.innerText.trim();
            if (idText.isNotEmpty) allIds.add(idText);
          }
        }

        for (var dependor in dep.findElements('dependors')) {
          for (var idElem in dependor.findElements('id')) {
            final idText = idElem.innerText.trim();
            if (idText.isNotEmpty) allIds.add(idText);
          }
        }

        // Add all file IDs
        for (var fileId in allIds) {
          final existingFiles = List<ECUFile>.from(ecuMap[ecuName]!.files);
          if (!existingFiles.any(
            (f) => f.id.toLowerCase() == fileId.toLowerCase(),
          )) {
            existingFiles.add(
              ECUFile(
                processClass: 'DEP',
                id: fileId,
                mainVersion: '000',
                subVersion: '000',
                patchVersion: '000',
              ),
            );
            ecuMap[ecuName] = ecuMap[ecuName]!.copyWith(files: existingFiles);
          }
        }
      }
    } catch (e, stack) {
      debugPrint('Error parsing $path: $e\n$stack');
    }
  }

  /// Select an ECU and load its files
  Future<void> selectECU(String ecuName) async {
    _selectedECU = ecuName;
    _setLoading(true, 'Loading files for $ecuName...');

    try {
      final ecu = _ecus.firstWhere(
        (e) => e.name == ecuName,
        orElse: () => ECU(name: ecuName, variant: '', address: 0),
      );

      _files = await _findFilesForECU(ecu);
      _setStatus('Found ${_files.length} files for $ecuName');
      notifyListeners();
    } catch (e) {
      _setStatus('Error: $e');
      _files.clear();
    } finally {
      _setLoading(false);
    }
  }

  /// Find files for an ECU - searches in file index
  Future<List<ECUFile>> _findFilesForECU(ECU ecu) async {
    final foundFiles = <ECUFile>[];
    final addedPaths = <String>{};

    for (var ecuFile in ecu.files) {
      final fileId = ecuFile.id.toLowerCase();
      bool found = false;

      // Search in file index
      if (_fileIndex.containsKey(fileId)) {
        for (var path in _fileIndex[fileId]!) {
          if (addedPaths.contains(path)) continue;

          final filename = path
              .split(Platform.pathSeparator)
              .last
              .toLowerCase();
          final parts = filename.split('_');

          String processClass = 'UNKNOWN';
          if (parts.isNotEmpty) {
            processClass = parts[0].toUpperCase();
          }

          String mainVer = '000', subVer = '000', patchVer = '000';
          if (parts.length >= 5) {
            mainVer = parts[2];
            subVer = parts[3];
            patchVer = parts[4].split('.')[0];
          }

          foundFiles.add(
            ECUFile(
              processClass: processClass,
              id: fileId,
              mainVersion: mainVer,
              subVersion: subVer,
              patchVersion: patchVer,
              path: path,
              status: FileStatus.found,
            ),
          );
          addedPaths.add(path);
          found = true;
        }
      }

      if (!found) {
        // Try to find by searching in all indexed files
        for (var entry in _fileIndex.entries) {
          if (entry.key.contains(fileId) || fileId.contains(entry.key)) {
            for (var path in entry.value) {
              if (addedPaths.contains(path)) continue;

              final filename = path
                  .split(Platform.pathSeparator)
                  .last
                  .toLowerCase();
              final parts = filename.split('_');

              String processClass = 'UNKNOWN';
              if (parts.isNotEmpty) {
                processClass = parts[0].toUpperCase();
              }

              foundFiles.add(
                ECUFile(
                  processClass: processClass,
                  id: entry.key,
                  mainVersion: parts.length >= 3 ? parts[2] : '000',
                  subVersion: parts.length >= 4 ? parts[3] : '000',
                  patchVersion: parts.length >= 5
                      ? parts[4].split('.')[0]
                      : '000',
                  path: path,
                  status: FileStatus.found,
                ),
              );
              addedPaths.add(path);
              found = true;
              break;
            }
          }
          if (found) break;
        }
      }

      if (!found) {
        foundFiles.add(ecuFile.copyWith(status: FileStatus.missing));
      }
    }

    return foundFiles;
  }

  /// Find a file by pattern
  String? findFile(
    String processClass,
    String id,
    String main,
    String sub,
    String patch,
  ) {
    final idLower = id.toLowerCase();
    final classLower = processClass.toLowerCase();

    final searchPattern =
        '${classLower}_${idLower}_${main.padLeft(3, '0')}_${sub.padLeft(3, '0')}_${patch.padLeft(3, '0')}';

    if (_fileIndex.containsKey(idLower)) {
      for (var path in _fileIndex[idLower]!) {
        if (path.toLowerCase().contains(searchPattern)) {
          return path;
        }
      }

      for (var path in _fileIndex[idLower]!) {
        final pathLower = path.toLowerCase();
        if (pathLower.contains(classLower) && pathLower.contains(idLower)) {
          return path;
        }
      }

      return _fileIndex[idLower]!.first;
    }

    return null;
  }

  /// Find file by ID only (broader search)
  String? _findFileByIdOnly(String id) {
    final idLower = id.toLowerCase();

    // Direct lookup
    if (_fileIndex.containsKey(idLower)) {
      return _fileIndex[idLower]!.first;
    }

    // Partial match
    for (var entry in _fileIndex.entries) {
      if (entry.key.contains(idLower) || idLower.contains(entry.key)) {
        return entry.value.first;
      }
    }

    return null;
  }

  /// Get real ECU data from psdzdata files for simulation
  Future<Map<String, dynamic>> getECUDataForSimulation(ECU ecu) async {
    final ecuData = <String, dynamic>{
      'name': ecu.name,
      'variant': ecu.variant,
      'address': ecu.address,
      'files': <Map<String, dynamic>>[],
    };

    for (var ecuFile in ecu.files) {
      final foundPath = findFile(
        ecuFile.processClass,
        ecuFile.id,
        ecuFile.mainVersion,
        ecuFile.subVersion,
        ecuFile.patchVersion,
      );

      if (foundPath != null) {
        final fileData = await _readECUFileData(foundPath, ecuFile);
        ecuData['files'].add(fileData);
      }
    }

    return ecuData;
  }

  /// Read ECU file data for simulation
  Future<Map<String, dynamic>> _readECUFileData(
    String path,
    ECUFile ecuFile,
  ) async {
    final file = File(path);
    final fileData = <String, dynamic>{
      'processClass': ecuFile.processClass,
      'id': ecuFile.id,
      'version': ecuFile.version,
      'path': path,
      'size': await file.length(),
    };

    // Read header data for BTLD, SWFL, CAFD files
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.length >= 32) {
        fileData['headerBytes'] = bytes.sublist(0, 32);
      }
    }

    return fileData;
  }

  /// Extract files to output folder (flat structure)
  Future<int> extractFiles(
    List<ECUFile> filesToExtract,
    String outputFolder,
  ) async {
    _setLoading(true, 'Extracting files...');
    int count = 0;

    try {
      final outputDir = Directory(outputFolder);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      for (var i = 0; i < filesToExtract.length; i++) {
        final file = filesToExtract[i];
        if (file.path != null && file.path!.isNotEmpty) {
          final srcFile = File(file.path!);
          if (await srcFile.exists()) {
            final destPath =
                '$outputFolder/${srcFile.path.split(Platform.pathSeparator).last}';
            await srcFile.copy(destPath);
            count++;
          }
        }

        _progress = (i + 1) / filesToExtract.length;
        _setStatus('Extracting ${i + 1}/${filesToExtract.length}...');
        notifyListeners();
      }

      _setStatus('Extracted $count files to $outputFolder');
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      _setLoading(false);
    }

    return count;
  }

  /// Extract files preserving folder structure
  Future<int> extractFilesWithStructure(
    List<ECUFile> filesToExtract,
    String outputFolder,
  ) async {
    _setLoading(true, 'Extracting files with folder structure...');
    int count = 0;

    try {
      final baseOut = _ensurePsdzdataOutputRoot(outputFolder);

      for (var i = 0; i < filesToExtract.length; i++) {
        final file = filesToExtract[i];
        final srcPath = file.path;
        if (srcPath != null && srcPath.isNotEmpty) {
          final srcFile = File(srcPath);
          if (await srcFile.exists()) {
            final relative = _relativePathUnderPsdzdata(srcPath);
            final destPath = relative != null
                ? p.join(baseOut, relative)
                : p.join(
                    outputFolder,
                    file.processClass.toLowerCase(),
                    p.basename(srcPath),
                  );

            final destDir = Directory(p.dirname(destPath));
            if (!await destDir.exists()) {
              await destDir.create(recursive: true);
            }

            await srcFile.copy(destPath);
            count++;
          }
        }

        _progress = filesToExtract.isEmpty
            ? 1
            : (i + 1) / filesToExtract.length;
        _setStatus('Extracting ${i + 1}/${filesToExtract.length}...');
        notifyListeners();
      }

      _setStatus(
        'Extracted $count files (with PSDZ structure) to $outputFolder',
      );
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      _setLoading(false);
    }

    return count;
  }

  /// Extract all ECUs from TAL/SVT file with folder structure
  Future<int> extractTALECUs(
    String outputFolder, {
    bool preserveStructure = true,
    List<String>? ecuFilter,
  }) async {
    if (_currentTALFile == null) {
      _setStatus('No TAL/SVT file loaded');
      return 0;
    }

    _setLoading(true, 'Extracting ECUs from ${_currentTALFile!.filename}...');
    int totalCount = 0;

    try {
      // Ensure file index is built
      if (_fileIndex.isEmpty) {
        _setStatus('Building file index...');
        await _buildFileIndex();
      }

      // Build unique list of source paths (avoids duplicates across ECUs)
      final uniqueSrc = <String>{};
      final jobs = <({String srcPath, String ecuName, ECUFile ecuFile})>[];

      // Filter ECUs if ecuFilter is provided
      final targetEcus = ecuFilter != null
          ? _currentTALFile!.ecus
                .where((e) => ecuFilter.contains(e.name))
                .toList()
          : _currentTALFile!.ecus;

      for (final ecu in targetEcus) {
        for (final ecuFile in ecu.files) {
          // First check if ecuFile already has a path
          String? foundPath = ecuFile.path;

          // If no path, try to find it
          if (foundPath == null || foundPath.isEmpty) {
            foundPath = findFile(
              ecuFile.processClass,
              ecuFile.id,
              ecuFile.mainVersion,
              ecuFile.subVersion,
              ecuFile.patchVersion,
            );
          }

          // If still not found, try broader search
          if (foundPath == null || foundPath.isEmpty) {
            foundPath = _findFileByIdOnly(ecuFile.id);
          }

          if (foundPath == null || foundPath.isEmpty) continue;
          if (uniqueSrc.add(foundPath)) {
            jobs.add((srcPath: foundPath, ecuName: ecu.name, ecuFile: ecuFile));
          }
        }
      }

      final baseOut = preserveStructure
          ? _ensurePsdzdataOutputRoot(outputFolder)
          : outputFolder;
      for (var i = 0; i < jobs.length; i++) {
        final job = jobs[i];
        final srcFile = File(job.srcPath);
        if (await srcFile.exists()) {
          late final String destPath;
          if (preserveStructure) {
            String? relative = _relativePathUnderPsdzdata(job.srcPath);

            // Fallback: try to find 'swe' in path
            if (relative == null) {
              final lower = job.srcPath.toLowerCase();
              final sweIndex = lower.indexOf(
                '${Platform.pathSeparator}swe${Platform.pathSeparator}',
              );
              if (sweIndex != -1) {
                relative = job.srcPath.substring(sweIndex + 1);
              }
            }

            destPath = relative != null
                ? p.join(baseOut, relative)
                : p.join(
                    baseOut,
                    'swe',
                    job.ecuFile.processClass.toLowerCase(),
                    p.basename(job.srcPath),
                  );
          } else {
            destPath = p.join(baseOut, job.ecuName, p.basename(job.srcPath));
          }

          final destDir = Directory(p.dirname(destPath));
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          await srcFile.copy(destPath);
          totalCount++;
        }

        _progress = jobs.isEmpty ? 1 : (i + 1) / jobs.length;
        _setStatus('Extracting ${i + 1}/${jobs.length}...');
        notifyListeners();
      }

      _setStatus(
        'Extracted $totalCount files from ${_currentTALFile!.ecus.length} ECUs',
      );
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      _setLoading(false);
    }

    return totalCount;
  }

  /// Extract a single ECU's files from TAL/SVT
  Future<int> extractSingleECU(String ecuName, String outputFolder) async {
    if (_currentTALFile == null) {
      _setStatus('No TAL/SVT file loaded');
      return 0;
    }

    final targetEcu = _currentTALFile!.ecus
        .where((e) => e.name == ecuName)
        .firstOrNull;
    if (targetEcu == null) {
      _setStatus('ECU not found: $ecuName');
      return 0;
    }

    _setLoading(true, 'Extracting ECU: $ecuName...');
    int count = 0;

    try {
      if (_fileIndex.isEmpty) {
        await _buildFileIndex();
      }

      final ecuDir = Directory(p.join(outputFolder, ecuName));
      if (!await ecuDir.exists()) {
        await ecuDir.create(recursive: true);
      }

      for (var i = 0; i < targetEcu.files.length; i++) {
        final ecuFile = targetEcu.files[i];
        String? foundPath = ecuFile.path;

        if (foundPath == null || foundPath.isEmpty) {
          foundPath = findFile(
            ecuFile.processClass,
            ecuFile.id,
            ecuFile.mainVersion,
            ecuFile.subVersion,
            ecuFile.patchVersion,
          );
        }

        if (foundPath == null || foundPath.isEmpty) {
          foundPath = _findFileByIdOnly(ecuFile.id);
        }

        if (foundPath != null && foundPath.isNotEmpty) {
          final srcFile = File(foundPath);
          if (await srcFile.exists()) {
            final destPath = p.join(ecuDir.path, p.basename(foundPath));
            await srcFile.copy(destPath);
            count++;
          }
        }

        _progress = (i + 1) / targetEcu.files.length;
        notifyListeners();
      }

      _setStatus('Extracted $count files for ECU: $ecuName');
    } catch (e) {
      _setStatus('Error: $e');
    } finally {
      _setLoading(false);
    }

    return count;
  }

  /// Save current TAL/SVT file to disk
  Future<void> saveTALFile(String path) async {
    if (_currentTALFile == null) {
      throw Exception('No TAL/SVT file loaded');
    }

    _setLoading(true, 'Saving TAL/SVT file...');

    try {
      // Build XML document from current TAL file data
      final buffer = StringBuffer();
      buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');

      if (_currentTALFile!.type == TALFileType.tal) {
        buffer.writeln('<TAL>');
        if (_currentTALFile!.vin != null) {
          buffer.writeln('  <vin>${_currentTALFile!.vin}</vin>');
        }
        if (_currentTALFile!.series != null) {
          buffer.writeln('  <baureihe>${_currentTALFile!.series}</baureihe>');
        }

        for (var ecu in _currentTALFile!.ecus) {
          buffer.writeln('  <talLine>');
          buffer.writeln('    <ecu_name>${ecu.name}</ecu_name>');
          for (var file in ecu.files) {
            buffer.writeln('    <file>');
            buffer.writeln('      <id>${file.id}</id>');
            buffer.writeln(
              '      <processClass>${file.processClass}</processClass>',
            );
            buffer.writeln(
              '      <version>${file.mainVersion}.${file.subVersion}.${file.patchVersion}</version>',
            );
            buffer.writeln('    </file>');
          }
          buffer.writeln('  </talLine>');
        }
        buffer.writeln('</TAL>');
      } else {
        buffer.writeln('<SVT>');
        if (_currentTALFile!.vin != null) {
          buffer.writeln('  <vin>${_currentTALFile!.vin}</vin>');
        }
        if (_currentTALFile!.series != null) {
          buffer.writeln('  <baureihe>${_currentTALFile!.series}</baureihe>');
        }

        for (var ecu in _currentTALFile!.ecus) {
          buffer.writeln('  <ecu name="${ecu.name}">');
          for (var file in ecu.files) {
            buffer.writeln('    <sgbm_id>${file.id}</sgbm_id>');
          }
          buffer.writeln('  </ecu>');
        }
        buffer.writeln('</SVT>');
      }

      await File(path).writeAsString(buffer.toString());
      _setStatus('Saved: ${p.basename(path)}');
    } catch (e) {
      _setStatus('Save error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Load TAL/SVT file
  Future<void> loadTALFile(String path) async {
    _setLoading(true, 'Loading TAL/SVT file...');

    try {
      final file = File(path);
      if (!await file.exists()) {
        _setStatus('Error: File not found at $path');
        _setLoading(false);
        return;
      }

      final content = await file.readAsString();
      final document = XmlDocument.parse(content);
      final root = document.rootElement;
      final rootTagLower = root.name.local.toLowerCase();

      TALFileType type = TALFileType.unknown;
      if (rootTagLower.contains('tal') || content.contains('talLine')) {
        type = TALFileType.tal;
      } else if (rootTagLower.contains('svt') || content.contains('<ecu ')) {
        type = TALFileType.svt;
      } else if (rootTagLower.contains('fa') || content.contains('FA_')) {
        type = TALFileType.fa;
      }

      String? vin;
      String? series;
      String? iStep;
      List<ECU> ecus = [];

      // Extract VIN (attributes first, then element text)
      vin = _extractXmlValue(
        document,
        attributeNames: const ['vin', 'VIN', 'Vin', 'fa_vin', 'FA_VIN'],
        elementNames: const ['vin', 'VIN', 'Vin', 'fa_vin', 'FA_VIN'],
        minLength: 10,
      );

      // Extract series/baureihe
      series = _extractXmlValue(
        document,
        attributeNames: const [
          'baureihe',
          'Baureihe',
          'series',
          'fa_br',
          'FA_BR',
        ],
        elementNames: const [
          'baureihe',
          'Baureihe',
          'series',
          'fa_br',
          'FA_BR',
        ],
      );

      // Extract I-Step
      iStep = _extractXmlValue(
        document,
        attributeNames: const ['iStep', 'I_STEP', 'i-step', 'istep'],
        elementNames: const [
          'iStep',
          'I_STEP',
          'istep',
          'I_STUFE_WERK',
          'I_STUFE_HO',
          'I_STUFE',
          'IStufe',
          'IStufeWerk',
        ],
      );

      if (type == TALFileType.tal) {
        ecus = _parseTAL(document);
      } else if (type == TALFileType.svt) {
        ecus = _parseSVT(document);
      } else {
        ecus = _parseTAL(document);
        if (ecus.isEmpty) {
          ecus = _parseSVT(document);
        }
      }

      for (var ecu in ecus) {
        for (var i = 0; i < ecu.files.length; i++) {
          final ecuFile = ecu.files[i];
          final foundPath = findFile(
            ecuFile.processClass,
            ecuFile.id,
            ecuFile.mainVersion,
            ecuFile.subVersion,
            ecuFile.patchVersion,
          );
          if (foundPath != null) {
            ecu.files[i] = ecuFile.copyWith(
              path: foundPath,
              status: FileStatus.found,
            );
          } else {
            ecu.files[i] = ecuFile.copyWith(status: FileStatus.missing);
          }
        }
      }

      _currentTALFile = TALFile(
        path: path,
        filename: path.split(Platform.pathSeparator).last,
        type: type,
        vin: vin,
        series: series,
        iStep: iStep,
        ecus: ecus,
        lastModified: await file.lastModified(),
        originalContent: content,
      );

      debugPrint('Loaded TAL/SVT: ${ecus.length} ECUs, type: ${type.name}');
      _setStatus('Loaded ${type.name.toUpperCase()}: ${ecus.length} ECUs');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('Error loading TAL/SVT: $e\n$stack');
      _setStatus('Error: $e');
      _currentTALFile = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Parse TAL file
  List<ECU> _parseTAL(XmlDocument document) {
    final ecus = <ECU>[];
    final ecuMap = <String, ECU>{};

    for (var talLine in document.findAllElements('talLine')) {
      final baseVariant =
          talLine.getAttribute('baseVariant') ??
          talLine.getAttribute('basevariant') ??
          'Unknown';
      final diagAddr =
          talLine.getAttribute('diagAddress') ??
          talLine.getAttribute('diagaddress') ??
          '0';

      final files = <ECUFile>[];

      final actionTypes = [
        'blFlash',
        'swDeploy',
        'cdDeploy',
        'IBADeploy',
        'ibaDeploy',
        'hwDeinstall',
        'hwInstall',
        'swDeinstall',
        'activate',
        'cdActivate',
      ];

      for (var action in talLine.children.whereType<XmlElement>()) {
        final actionName = action.name.local;
        if (actionTypes.contains(actionName) ||
            actionName.toLowerCase().contains('deploy') ||
            actionName.toLowerCase().contains('flash')) {
          for (var sgbmid in action.findAllElements('sgbmid')) {
            final ecuFile = _parseSgbmId(sgbmid);
            if (ecuFile != null) files.add(ecuFile);
          }
          for (var sgbmid in action.findAllElements('SGBMID')) {
            final ecuFile = _parseSgbmId(sgbmid);
            if (ecuFile != null) files.add(ecuFile);
          }
        }
      }

      for (var sgbmid in talLine.findAllElements('sgbmid')) {
        final ecuFile = _parseSgbmId(sgbmid);
        if (ecuFile != null && !files.any((f) => f.id == ecuFile.id)) {
          files.add(ecuFile);
        }
      }

      if (files.isNotEmpty || baseVariant != 'Unknown') {
        if (ecuMap.containsKey(baseVariant)) {
          final existingFiles = List<ECUFile>.from(ecuMap[baseVariant]!.files);
          for (var f in files) {
            if (!existingFiles.any(
              (ef) => ef.id == f.id && ef.processClass == f.processClass,
            )) {
              existingFiles.add(f);
            }
          }
          ecuMap[baseVariant] = ecuMap[baseVariant]!.copyWith(
            files: existingFiles,
          );
        } else {
          ecuMap[baseVariant] = ECU(
            name: baseVariant,
            variant: baseVariant,
            address: _parseAddress(diagAddr),
            files: files,
          );
        }
      }
    }

    ecus.addAll(ecuMap.values);
    debugPrint('Parsed TAL: ${ecus.length} ECUs');
    return ecus;
  }

  /// Parse SVT file
  List<ECU> _parseSVT(XmlDocument document) {
    final ecus = <ECU>[];

    for (var ecuElem in document.findAllElements('ecu')) {
      final baseVariant =
          ecuElem.getAttribute('baseVariant') ??
          ecuElem.getAttribute('basevariant') ??
          'Unknown';

      int address = 0;
      final diagAddr =
          ecuElem.findElements('diagnosticAddress').firstOrNull ??
          ecuElem.findElements('DiagnosticAddress').firstOrNull;
      if (diagAddr != null) {
        address = _parseAddress(
          diagAddr.getAttribute('physicalOffset') ??
              diagAddr.getAttribute('PhysicalOffset') ??
              diagAddr.innerText.trim(),
        );
      }

      final files = <ECUFile>[];
      final addedIds = <String>{};

      for (var partId in ecuElem.findAllElements('partIdentification')) {
        final ecuFile = _parseSgbmId(partId);
        if (ecuFile != null) {
          final key = '${ecuFile.processClass}_${ecuFile.id}';
          if (!addedIds.contains(key)) {
            files.add(ecuFile);
            addedIds.add(key);
          }
        }
      }

      for (var svk in ecuElem.findAllElements('standardSVK')) {
        for (var partId in svk.findAllElements('partIdentification')) {
          final ecuFile = _parseSgbmId(partId);
          if (ecuFile != null) {
            final key = '${ecuFile.processClass}_${ecuFile.id}';
            if (!addedIds.contains(key)) {
              files.add(ecuFile);
              addedIds.add(key);
            }
          }
        }
      }

      for (var svkType in ['hweSvk', 'cafdSvk', 'sgbmSvk']) {
        for (var svk in ecuElem.findAllElements(svkType)) {
          for (var partId in svk.findAllElements('partIdentification')) {
            final ecuFile = _parseSgbmId(partId);
            if (ecuFile != null) {
              final key = '${ecuFile.processClass}_${ecuFile.id}';
              if (!addedIds.contains(key)) {
                files.add(ecuFile);
                addedIds.add(key);
              }
            }
          }
        }
      }

      if (files.isNotEmpty) {
        ecus.add(
          ECU(
            name: baseVariant,
            variant: baseVariant,
            address: address,
            files: files,
          ),
        );
      }
    }

    debugPrint('Parsed SVT: ${ecus.length} ECUs');
    return ecus;
  }

  /// Parse SGBMID element
  ECUFile? _parseSgbmId(XmlElement elem) {
    String? processClass, id, mainVer, subVer, patchVer;

    final tagMappings = {
      'processClass': ['processClass', 'ProcessClass', 'processclass', 'class'],
      'id': ['id', 'ID', 'Id'],
      'mainVersion': ['mainVersion', 'MainVersion', 'mainversion', 'main'],
      'subVersion': ['subVersion', 'SubVersion', 'subversion', 'sub'],
      'patchVersion': ['patchVersion', 'PatchVersion', 'patchversion', 'patch'],
    };

    for (var child in elem.childElements) {
      final tag = child.name.local;
      final text = child.innerText.trim();

      if (tagMappings['processClass']!.contains(tag))
        processClass = text;
      else if (tagMappings['id']!.contains(tag))
        id = text;
      else if (tagMappings['mainVersion']!.contains(tag))
        mainVer = text;
      else if (tagMappings['subVersion']!.contains(tag))
        subVer = text;
      else if (tagMappings['patchVersion']!.contains(tag))
        patchVer = text;
    }

    processClass ??= elem.getAttribute('processClass');
    id ??= elem.getAttribute('id');
    mainVer ??= elem.getAttribute('mainVersion');
    subVer ??= elem.getAttribute('subVersion');
    patchVer ??= elem.getAttribute('patchVersion');

    if (processClass != null &&
        processClass.isNotEmpty &&
        id != null &&
        id.isNotEmpty) {
      return ECUFile(
        processClass: processClass.toUpperCase(),
        id: id,
        mainVersion: mainVer?.padLeft(3, '0') ?? '000',
        subVersion: subVer?.padLeft(3, '0') ?? '000',
        patchVersion: patchVer?.padLeft(3, '0') ?? '000',
      );
    }

    return null;
  }

  /// Returns path relative to PSDZ root (psdzPath) if the file is inside PSDZDATA.
  /// Output uses platform separators via `package:path`.
  String? _relativePathUnderPsdzdata(String absolutePath) {
    try {
      final psdzRoot = p.normalize(_psdzPath);
      final abs = p.normalize(absolutePath);
      if (abs.toLowerCase() == psdzRoot.toLowerCase()) return '';
      if (p.isWithin(psdzRoot, abs)) {
        final rel = p.relative(abs, from: psdzRoot);
        return rel == '.' ? '' : rel;
      }
    } catch (_) {
      // fall through
    }
    return null;
  }

  /// Ensures extraction root contains a `psdzdata` folder (unless the user already selected it).
  String _ensurePsdzdataOutputRoot(String outputFolder) {
    final base = p.normalize(outputFolder);
    final tail = p.basename(base).toLowerCase();
    return tail == 'psdzdata' ? base : p.join(base, 'psdzdata');
  }

  String? _extractXmlValue(
    XmlDocument document, {
    required List<String> attributeNames,
    required List<String> elementNames,
    int minLength = 1,
  }) {
    final root = document.rootElement;

    // Attributes (root)
    for (final name in attributeNames) {
      final v = root.getAttribute(name);
      if (v != null) {
        final t = v.trim();
        if (t.length >= minLength) return t;
      }
    }

    // Elements anywhere
    for (final name in elementNames) {
      for (final elem in document.findAllElements(name)) {
        final t = elem.innerText.trim();
        if (t.length >= minLength) return t;
      }
    }

    return null;
  }

  /// Save SVT file with modifications
  Future<bool> saveSVTFile(String path) async {
    if (_currentTALFile == null) return false;

    try {
      final file = File(path);
      // Generate new content based on current state
      final content = _generateSVTXml();

      await file.writeAsString(content);
      _setStatus('Saved SVT file to $path');
      notifyListeners();
      return true;
    } catch (e) {
      _setStatus('Error saving file: $e');
      return false;
    }
  }

  /// Delete ECU from current TAL/SVT
  void deleteECU(int index) {
    if (_currentTALFile == null ||
        index < 0 ||
        index >= _currentTALFile!.ecus.length)
      return;

    final updatedEcus = List<ECU>.from(_currentTALFile!.ecus);
    updatedEcus.removeAt(index);

    _currentTALFile = _currentTALFile!.copyWith(
      ecus: updatedEcus,
      isModified: true,
    );
    notifyListeners();
  }

  /// Update ECU in current TAL/SVT
  void updateECU(int index, ECU newEcu) {
    if (_currentTALFile == null ||
        index < 0 ||
        index >= _currentTALFile!.ecus.length)
      return;

    final updatedEcus = List<ECU>.from(_currentTALFile!.ecus);
    updatedEcus[index] = newEcu;

    _currentTALFile = _currentTALFile!.copyWith(
      ecus: updatedEcus,
      isModified: true,
    );
    notifyListeners();
  }

  /// Generate SVT XML from current TALFile
  String _generateSVTXml() {
    if (_currentTALFile == null) return '';

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element(
      'SVT',
      nest: () {
        if (_currentTALFile!.vin != null) {
          builder.element('VIN', nest: _currentTALFile!.vin);
        }

        if (_currentTALFile!.iStep != null) {
          builder.element('I_STUFE_IST', nest: _currentTALFile!.iStep);
        }

        for (var ecu in _currentTALFile!.ecus) {
          builder.element(
            'ECU',
            nest: () {
              builder.element('NAME', nest: ecu.name);
              builder.attribute(
                'DIAGNOSE_ADRESSE',
                ecu.addressHex.replaceAll('0x', ''),
              );

              for (var file in ecu.files) {
                builder.element(
                  'SWE',
                  nest: () {
                    // Reconstruct SGBM_ID
                    // Format: CLASS_ID_VER_VER_VER
                    final sgbmId =
                        '${file.processClass.toUpperCase()}_${file.id}_${file.mainVersion}_${file.subVersion}_${file.patchVersion}';
                    builder.element('SGBM_ID', nest: sgbmId);

                    builder.element(
                      'SW_UNIT_TYPE',
                      nest: file.processClass.toUpperCase(),
                    );
                  },
                );
              }
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Filter library files by VIN or series
  List<LibraryScanResult> filterLibrary({String? vin, String? series}) {
    return _libraryFiles.where((file) {
      if (vin != null && vin.isNotEmpty) {
        if (file.vin == null ||
            !file.vin!.toLowerCase().contains(vin.toLowerCase())) {
          return false;
        }
      }
      if (series != null && series.isNotEmpty) {
        if (file.series == null ||
            !file.series!.toLowerCase().contains(series.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Get statistics for current state
  Map<String, int> getStatistics() {
    int totalFiles = 0;
    int foundFiles = 0;
    int missingFiles = 0;

    for (var ecu in _ecus) {
      for (var file in ecu.files) {
        totalFiles++;
        if (_fileIndex.containsKey(file.id.toLowerCase())) {
          foundFiles++;
        } else {
          missingFiles++;
        }
      }
    }

    return {
      'series': _series.length,
      'iSteps': _iSteps.length,
      'ecus': _ecus.length,
      'totalFiles': totalFiles,
      'foundFiles': foundFiles,
      'missingFiles': missingFiles,
      'indexedFiles': _fileIndex.length,
    };
  }

  /// Scan library for TAL/SVT files
  /// Scans user-specified paths plus auto-scan path and PSDZ root
  /// Optimized with batch processing to prevent UI freeze
  Future<void> scanLibrary() async {
    _setLoading(true, 'Scanning library...');
    _libraryFiles.clear();

    try {
      // Collect all paths to scan (user paths + auto paths)
      final Set<String> allPaths = {};

      // Add user-specified paths
      for (var p in _scanPaths.split(',')) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) {
          allPaths.add(trimmed);
        }
      }

      // Add auto-scan path (C:/data)
      if (_autoScanPath.isNotEmpty) {
        allPaths.add(_autoScanPath);
      }

      // Add PSDZ root path
      if (_psdzPath.isNotEmpty && Directory(_psdzPath).existsSync()) {
        allPaths.add(_psdzPath);
      }

      // Add common locations
      final commonPaths = [
        'C:/Data/TAL',
        'C:/Data/SVT',
        'C:/Data/FA',
        'C:/data/TAL',
        'C:/data/SVT',
        'C:/data/FA',
      ];
      for (var cp in commonPaths) {
        if (Directory(cp).existsSync()) {
          allPaths.add(cp);
        }
      }

      int scannedCount = 0;
      int totalPaths = allPaths.length;

      // First collect all XML files
      final List<String> allXmlFiles = [];

      for (var scanPath in allPaths) {
        scannedCount++;
        _setStatus('Collecting files ($scannedCount/$totalPaths): $scanPath');

        final dir = Directory(scanPath);
        if (!await dir.exists()) continue;

        await for (var entity in dir.list(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.xml')) {
            allXmlFiles.add(entity.path);
          }
        }
      }

      _setStatus('Processing ${allXmlFiles.length} XML files...');

      // Process files in batches to prevent UI freeze
      const batchSize = 20;
      int processed = 0;

      for (var i = 0; i < allXmlFiles.length; i += batchSize) {
        final batch = allXmlFiles.skip(i).take(batchSize);

        for (var filePath in batch) {
          final result = await _quickScanXML(filePath);
          if (result != null) {
            // Avoid duplicates
            if (!_libraryFiles.any((f) => f.path == result.path)) {
              _libraryFiles.add(result);
            }
          }
          processed++;
        }

        // Update UI every batch
        if (processed % 50 == 0 || processed == allXmlFiles.length) {
          _setStatus(
            'Scanned $processed/${allXmlFiles.length} files, found ${_libraryFiles.length} TAL/SVT',
          );
          notifyListeners();
          // Yield to UI thread
          await Future.delayed(Duration.zero);
        }
      }

      // Sort by filename
      _libraryFiles.sort((a, b) => a.filename.compareTo(b.filename));

      _setStatus(
        'Found ${_libraryFiles.length} TAL/SVT files in ${allPaths.length} locations',
      );
      notifyListeners();
    } catch (e) {
      _setStatus('Scan error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Quick scan XML file for basic info - Enhanced detection
  Future<LibraryScanResult?> _quickScanXML(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final document = XmlDocument.parse(content);
      final root = document.rootElement;
      final rootName = root.name.local.toLowerCase();
      final filename = path.split(Platform.pathSeparator).last.toLowerCase();

      TALFileType type = TALFileType.unknown;

      // Enhanced TAL detection
      if (rootName.contains('tal') ||
          rootName == 'transactionlist' ||
          content.contains('<talLine') ||
          content.contains('<TAL_LINE') ||
          content.contains('tal_line') ||
          filename.contains('_tal') ||
          filename.startsWith('tal_')) {
        type = TALFileType.tal;
      }
      // Enhanced SVT detection
      else if (rootName.contains('svt') ||
          rootName == 'svt_soll' ||
          rootName == 'svt_ist' ||
          content.contains('<ecu ') ||
          content.contains('<ecu>') ||
          content.contains('<ECU ') ||
          content.contains('<ECU>') ||
          content.contains('sgbm_id') ||
          content.contains('SGBM_ID') ||
          filename.contains('_svt') ||
          filename.startsWith('svt_')) {
        type = TALFileType.svt;
      }
      // FA file detection
      else if (rootName.contains('fa') ||
          rootName == 'fahrzeugauftrag' ||
          content.contains('<fa_version') ||
          content.contains('<FA_VERSION') ||
          filename.contains('_fa') ||
          filename.startsWith('fa_')) {
        type = TALFileType.fa;
      }

      // Still return unknown files if they have ECU data
      if (type == TALFileType.unknown) {
        final hasEcuData = content.contains('ecu') || content.contains('ECU');
        if (!hasEcuData) return null;
        type = TALFileType.svt; // Assume SVT-like if has ECU references
      }

      String? vin;
      String? series;
      int ecuCount = 0;

      // Find VIN
      for (var elem in document.findAllElements('vin')) {
        if (elem.innerText.length >= 10) {
          vin = elem.innerText.trim();
          break;
        }
      }
      if (vin == null) {
        for (var elem in document.findAllElements('VIN')) {
          if (elem.innerText.length >= 10) {
            vin = elem.innerText.trim();
            break;
          }
        }
      }

      // Find Series
      for (var elem in document.findAllElements('baureihe')) {
        series = elem.innerText.trim();
        break;
      }
      if (series == null) {
        for (var elem in document.findAllElements('BAUREIHE')) {
          series = elem.innerText.trim();
          break;
        }
      }
      if (series == null) {
        for (var elem in document.findAllElements('ereihe')) {
          series = elem.innerText.trim();
          break;
        }
      }

      // Count ECUs
      if (type == TALFileType.tal) {
        ecuCount = document.findAllElements('talLine').length;
        if (ecuCount == 0) {
          ecuCount = document.findAllElements('TAL_LINE').length;
        }
      } else {
        ecuCount = document.findAllElements('ecu').length;
        if (ecuCount == 0) {
          ecuCount = document.findAllElements('ECU').length;
        }
      }

      return LibraryScanResult(
        path: path,
        filename: path.split(Platform.pathSeparator).last,
        type: type.name.toUpperCase(),
        vin: vin,
        series: series,
        ecuCount: ecuCount,
      );
    } catch (e) {
      return null;
    }
  }

  int _parseAddress(String addr) {
    try {
      if (addr.startsWith('0x') || addr.startsWith('0X')) {
        return int.parse(addr.substring(2), radix: 16);
      }
      return int.tryParse(addr, radix: 16) ?? int.tryParse(addr) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void _setLoading(bool loading, [String? message]) {
    _isLoading = loading;
    if (message != null) _statusMessage = message;
    if (!loading) _progress = 0;
    notifyListeners();
  }

  void _setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  VehicleSeries? _findSeries(String seriesCode) {
    try {
      return _series.firstWhere((s) => s.code == seriesCode);
    } catch (_) {
      return null;
    }
  }

  IStep? _findIStepBestEffort(String istepName, {String? preferredSeries}) {
    // 1) Prefer currently loaded iSteps (usually the currently selected series)
    try {
      return _iSteps.firstWhere((i) => i.name == istepName);
    } catch (_) {
      // continue
    }

    // 2) If a preferred series was provided, search it first.
    if (preferredSeries != null) {
      final series = _findSeries(preferredSeries);
      if (series != null) {
        try {
          return series.iSteps.firstWhere((i) => i.name == istepName);
        } catch (_) {
          // continue
        }
      }
    }

    // 3) Fallback: scan all series (may contain duplicates, pick first match)
    for (final s in _series) {
      for (final i in s.iSteps) {
        if (i.name == istepName) return i;
      }
    }
    return null;
  }

  Future<List<ECU>> _loadEcusFromIStepPath(String istepPath) async {
    final ecuMap = <String, ECU>{};
    final mappingPath = '$istepPath/mapping';
    final mappingDir = Directory(mappingPath);

    if (!await mappingDir.exists()) return const [];

    await for (var file in mappingDir.list()) {
      if (file is File &&
          file.path.contains('sweseq_') &&
          file.path.toLowerCase().endsWith('.xml')) {
        await _parseSweseqFile(file.path, ecuMap);
      }
    }

    final list = ecuMap.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<int> _exportEcusResolved(
    List<ECU> ecus,
    String targetPath, {
    String? istepName,
    String? processClassFilter,
    bool preserveStructure = true,
  }) async {
    int copied = 0;
    final targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    for (var ecuIndex = 0; ecuIndex < ecus.length; ecuIndex++) {
      final ecu = ecus[ecuIndex];
      final destBase = istepName == null
          ? targetPath
          : '$targetPath/$istepName';
      final ecuDir = Directory('$destBase/${ecu.name}');
      await ecuDir.create(recursive: true);

      final resolvedFiles = await _findFilesForECU(ecu);
      final filesToCopy = resolvedFiles
          .where((f) => f.status == FileStatus.found)
          .where(
            (f) =>
                processClassFilter == null ||
                f.processClass == processClassFilter,
          )
          .toList();

      for (final file in filesToCopy) {
        if (file.path == null || file.path!.isEmpty) continue;
        final sourceFile = File(file.path!);
        if (!await sourceFile.exists()) continue;

        if (preserveStructure) {
          final lower = file.path!.toLowerCase();
          final marker =
              '${Platform.pathSeparator}swe${Platform.pathSeparator}';
          final idx = lower.indexOf(marker);
          final relative = idx == -1
              ? file.path!.split(Platform.pathSeparator).last
              : file.path!.substring(
                  idx + 1,
                ); // keep "swe/..." without leading slash

          final destPath = '${ecuDir.path}${Platform.pathSeparator}$relative';
          final destDir = Directory(File(destPath).parent.path);
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          await sourceFile.copy(destPath);
        } else {
          final fileName = file.path!.split(Platform.pathSeparator).last;
          await sourceFile.copy('${ecuDir.path}/$fileName');
        }
        copied++;
      }

      // Progress by ECU to avoid heavy pre-counts.
      _progress = ecus.isEmpty ? 0 : (ecuIndex + 1) / ecus.length;
      notifyListeners();
    }

    return copied;
  }

  /// Collect all found files for the currently loaded ECU list (current I-Step).
  /// Optional filter: limit to one process class (e.g., 'SWFL').
  Future<List<ECUFile>> collectFoundFilesForCurrentIStep({
    String? processClass,
  }) async {
    final out = <ECUFile>[];
    final addedPaths = <String>{};

    for (final ecu in _ecus) {
      final resolved = await _findFilesForECU(ecu);
      for (final f in resolved) {
        if (f.status != FileStatus.found) continue;
        if (processClass != null && f.processClass != processClass) continue;
        if (f.path == null || f.path!.isEmpty) continue;
        if (addedPaths.add(f.path!)) {
          out.add(f);
        }
      }
    }

    return out;
  }

  /// Export TAL/SVT files from PSDZ data with filter support
  /// Extracts files based on information written in SVT/TAL to proper structure
  Future<int> exportTALWithFilter({
    required String outputPath,
    String filterMode = 'all', // 'all', 'found', 'selected', 'byECU'
    String? selectedECUName,
    String? fileTypeFilter, // 'ALL', 'SWE', 'CAFD', 'SWFL', etc.
    bool preserveStructure = true,
  }) async {
    if (_currentTALFile == null) {
      _setStatus('No TAL/SVT file loaded');
      return 0;
    }

    _setLoading(true, 'Exporting with filter: $filterMode...');
    int totalCount = 0;

    try {
      // Ensure file index is built
      if (_fileIndex.isEmpty) {
        _setStatus('Building file index...');
        await _buildFileIndex();
      }

      // Determine which ECUs to process
      List<ECU> targetEcus;
      switch (filterMode) {
        case 'selected':
        case 'byECU':
          if (selectedECUName == null) {
            _setStatus('No ECU selected for export');
            return 0;
          }
          final ecu = _currentTALFile!.ecus
              .where((e) => e.name == selectedECUName)
              .firstOrNull;
          if (ecu == null) {
            _setStatus('ECU not found: $selectedECUName');
            return 0;
          }
          targetEcus = [ecu];
          break;
        case 'found':
          // Only ECUs with at least one found file
          targetEcus = _currentTALFile!.ecus.where((ecu) {
            return ecu.files.any((f) => f.status == FileStatus.found);
          }).toList();
          break;
        default:
          targetEcus = _currentTALFile!.ecus;
      }

      // Collect files to export
      final jobs = <({String srcPath, String ecuName, ECUFile ecuFile})>[];
      final uniqueSrc = <String>{};

      for (final ecu in targetEcus) {
        for (final ecuFile in ecu.files) {
          // Apply file type filter
          if (fileTypeFilter != null &&
              fileTypeFilter != 'ALL' &&
              ecuFile.processClass.toUpperCase() !=
                  fileTypeFilter.toUpperCase()) {
            continue;
          }

          // For 'found' mode, only export files with paths
          if (filterMode == 'found' &&
              (ecuFile.path == null || ecuFile.path!.isEmpty)) {
            continue;
          }

          String? foundPath = ecuFile.path;

          // If no path, try to find it
          if (foundPath == null || foundPath.isEmpty) {
            foundPath = findFile(
              ecuFile.processClass,
              ecuFile.id,
              ecuFile.mainVersion,
              ecuFile.subVersion,
              ecuFile.patchVersion,
            );
          }

          // Fallback: broader search
          if (foundPath == null || foundPath.isEmpty) {
            foundPath = _findFileByIdOnly(ecuFile.id);
          }

          if (foundPath == null || foundPath.isEmpty) continue;
          if (uniqueSrc.add(foundPath)) {
            jobs.add((srcPath: foundPath, ecuName: ecu.name, ecuFile: ecuFile));
          }
        }
      }

      if (jobs.isEmpty) {
        _setStatus('No files matched the filter criteria');
        return 0;
      }

      // Create output directory structure
      final baseOut = preserveStructure
          ? _ensurePsdzdataOutputRoot(outputPath)
          : outputPath;

      for (var i = 0; i < jobs.length; i++) {
        final job = jobs[i];
        final srcFile = File(job.srcPath);
        if (await srcFile.exists()) {
          late final String destPath;
          if (preserveStructure) {
            String? relative = _relativePathUnderPsdzdata(job.srcPath);

            // Fallback: try to find 'swe' in path
            if (relative == null) {
              final lower = job.srcPath.toLowerCase();
              final sweIndex = lower.indexOf(
                '${Platform.pathSeparator}swe${Platform.pathSeparator}',
              );
              if (sweIndex != -1) {
                relative = job.srcPath.substring(sweIndex + 1);
              }
            }

            destPath = relative != null
                ? p.join(baseOut, relative)
                : p.join(
                    baseOut,
                    'swe',
                    job.ecuFile.processClass.toLowerCase(),
                    p.basename(job.srcPath),
                  );
          } else {
            destPath = p.join(outputPath, job.ecuName, p.basename(job.srcPath));
          }

          final destDir = Directory(p.dirname(destPath));
          if (!await destDir.exists()) {
            await destDir.create(recursive: true);
          }
          await srcFile.copy(destPath);
          totalCount++;
        }

        _progress = jobs.isEmpty ? 1 : (i + 1) / jobs.length;
        _setStatus('Extracting ${i + 1}/${jobs.length}...');
        notifyListeners();
      }

      _setStatus(
        '✅ Exported $totalCount files (filter: $filterMode, structure: ${preserveStructure ? "PSDZ" : "flat"})',
      );
    } catch (e) {
      _setStatus('❌ Export error: $e');
    } finally {
      _setLoading(false);
    }

    return totalCount;
  }

  /// Export files by series
  Future<void> exportBySeries(
    String seriesCode,
    String targetPath, {
    bool preserveStructure = true,
  }) async {
    _setLoading(true, 'Exporting $seriesCode files...');

    try {
      final series = _findSeries(seriesCode);
      if (series == null || series.iSteps.isEmpty) {
        _setStatus('❌ Export error: Series $seriesCode not found');
        return;
      }

      int totalCopied = 0;
      for (var idx = 0; idx < series.iSteps.length; idx++) {
        final istep = series.iSteps[idx];
        _setStatus('Exporting $seriesCode / ${istep.name}...');
        notifyListeners();

        final ecusForStep = await _loadEcusFromIStepPath(istep.path);
        totalCopied += await _exportEcusResolved(
          ecusForStep,
          targetPath,
          istepName: istep.name,
          preserveStructure: preserveStructure,
        );

        // Progress by I-Step within the series
        _progress = series.iSteps.isEmpty
            ? 0
            : (idx + 1) / series.iSteps.length;
        notifyListeners();
      }

      _setStatus('✅ Exported $totalCopied files for $seriesCode');
    } catch (e) {
      _setStatus('❌ Export error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Export files by I-Step
  Future<void> exportByIStep(
    String iStep,
    String targetPath, {
    bool preserveStructure = true,
  }) async {
    _setLoading(true, 'Exporting $iStep files...');

    try {
      final istep = _findIStepBestEffort(
        iStep,
        preferredSeries: _selectedSeries,
      );
      if (istep == null) {
        _setStatus('❌ Export error: I-Step $iStep not found');
        return;
      }

      final ecusForStep = await _loadEcusFromIStepPath(istep.path);
      final copied = await _exportEcusResolved(
        ecusForStep,
        targetPath,
        preserveStructure: preserveStructure,
      );

      _setStatus('✅ Exported $copied files for $iStep');
    } catch (e) {
      _setStatus('❌ Export error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load FA file
  Future<void> loadFAFile(String path) async {
    _setLoading(true, 'Loading FA file...');

    try {
      final file = File(path);
      if (!await file.exists()) {
        _setStatus('❌ FA file not found');
        return;
      }

      final content = await file.readAsString();
      final document = XmlDocument.parse(content);

      // Extract VIN
      String? vin;
      for (var elem in document.findAllElements('vin')) {
        vin = elem.innerText.trim();
        if (vin.isNotEmpty) break;
      }

      // Extract series
      String? series;
      final standardFA = document.findAllElements('standardFA').firstOrNull;
      if (standardFA != null) {
        series = standardFA.getAttribute('series');
      }

      _setStatus('✅ Loaded FA: VIN=$vin, Series=$series');

      // Try to find matching SVT file
      final dir = file.parent;
      final svtPath = '${dir.path}/SVT_ECU.xml';
      if (await File(svtPath).exists()) {
        await loadTALFile(svtPath);
      }
    } catch (e) {
      _setStatus('❌ Load FA error: $e');
    } finally {
      _setLoading(false);
    }
  }
}

/// Top-level function for parsing XML in isolate
Map<String, dynamic> parseVehicleXml(Map<String, String> args) {
  final content = args['content']!;
  final type = args['type']!;

  String? vin;
  String? series;
  String? istep;
  int ecuCount = 0;

  try {
    final document = XmlDocument.parse(content);

    // Extract VIN
    for (var tagName in ['vin', 'VIN', 'Vin', 'fa_vin', 'FA_VIN']) {
      for (var elem in document.findAllElements(tagName)) {
        final text = elem.innerText.trim();
        if (text.length >= 10) {
          vin = text;
          break;
        }
      }
      if (vin != null) break;
    }

    // Extract series
    for (var tagName in ['baureihe', 'Baureihe', 'series', 'fa_br', 'FA_BR']) {
      for (var elem in document.findAllElements(tagName)) {
        final text = elem.innerText.trim();
        if (text.isNotEmpty) {
          series = text;
          break;
        }
      }
      if (series != null) break;
    }

    // Extract I-Step
    for (var tagName in ['iStep', 'istep', 'I_STUFE', 'i_stufe']) {
      for (var elem in document.findAllElements(tagName)) {
        final text = elem.innerText.trim();
        if (text.isNotEmpty) {
          istep = text;
          break;
        }
      }
      if (istep != null) break;
    }

    // Count ECUs
    if (type == 'TAL') {
      ecuCount = document.findAllElements('talLine').length;
    } else if (type == 'SVT') {
      ecuCount = document.findAllElements('ecu').length;
    }
  } catch (e) {
    // Ignore parsing errors in isolate
  }

  return {'vin': vin, 'series': series, 'istep': istep, 'ecuCount': ecuCount};
}

class LibraryScanResult {
  final String path;
  final String filename;
  final String type; // TAL, SVT, FA, BACKUP, CAFD
  final DateTime? modified;
  final int? size;
  final String? vin;
  final String? series;
  final int? ecuCount;

  LibraryScanResult({
    required this.path,
    required this.filename,
    required this.type,
    this.modified,
    this.size,
    this.vin,
    this.series,
    this.ecuCount,
  });
}
