/// BMW Backup Scanner Service
/// Scans C:\Data\Backup folder structure for vehicle data
///
/// Folder structure:
/// C:\Data\Backup\
///   {SERIES}_{VIN}\
///     {TIMESTAMP}\
///       FA.xml, SVT_ECU.xml, Report.txt, DTC_{VIN}.txt
///       VCM BACKUP\FA.xml, FP.xml
///       VCM MASTER\FA.xml
///       NCD\{ECU_NAME} [{ADDRESS}]\*.ncd
///       FSC\{ECU_NAME} [{ADDRESS}]\*.fsc
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

/// Backup vehicle info - represents a vehicle backup
class BackupVehicle {
  final String vin;
  final String series;
  final String folderPath;
  final String backupDate;
  final String? iStep;
  final String? vehicleName;

  // Files
  final File? faFile;
  final File? svtFile;
  final File? reportFile;
  final File? dtcFile;
  final File? fpFile;

  // ECU data
  final List<BackupEcu> ecus;
  final List<BackupFsc> fscs;

  // FA codes
  final List<String> saCodes;
  final List<String> eCodes;
  final String? typeKey;
  final String? colorCode;

  BackupVehicle({
    required this.vin,
    required this.series,
    required this.folderPath,
    required this.backupDate,
    this.iStep,
    this.vehicleName,
    this.faFile,
    this.svtFile,
    this.reportFile,
    this.dtcFile,
    this.fpFile,
    this.ecus = const [],
    this.fscs = const [],
    this.saCodes = const [],
    this.eCodes = const [],
    this.typeKey,
    this.colorCode,
  });

  String get vinShort => vin.length >= 7 ? vin.substring(vin.length - 7) : vin;

  String get displayName {
    final parts = <String>[series, vinShort];
    if (vehicleName != null) parts.add(vehicleName!);
    return parts.join(' - ');
  }

  int get ecuCount => ecus.length;
  int get ncdFileCount => ecus.fold(0, (sum, e) => sum + e.ncdFiles.length);
  int get fscFileCount => fscs.fold(0, (sum, f) => sum + f.fscFiles.length);

  bool get hasFA => faFile != null;
  bool get hasSVT => svtFile != null;
  bool get isComplete => hasFA && hasSVT;
}

/// Backup ECU info
class BackupEcu {
  final String name;
  final String address;
  final String folderPath;
  final List<File> ncdFiles;
  final String? variantCoding;
  final String? hwel;
  final String? swel;

  BackupEcu({
    required this.name,
    required this.address,
    required this.folderPath,
    this.ncdFiles = const [],
    this.variantCoding,
    this.hwel,
    this.swel,
  });

  int get addressInt {
    try {
      return int.parse(address, radix: 16);
    } catch (_) {
      return 0;
    }
  }

  String get displayName => '$name [0x$address]';

  /// Get address as int for ECU loading
  int get addressAsInt => addressInt;
}

/// Backup FSC info
class BackupFsc {
  final String ecuName;
  final String address;
  final String folderPath;
  final List<File> fscFiles;
  final List<String> fscCodes;

  BackupFsc({
    required this.ecuName,
    required this.address,
    required this.folderPath,
    this.fscFiles = const [],
    this.fscCodes = const [],
  });
}

/// Extensions for BackupVehicle
extension BackupVehicleExtensions on BackupVehicle {
  String get folderName => folderPath.split(Platform.pathSeparator).last;

  /// Get list of FSC codes from all FSC entries
  List<String> get fscCodes {
    final codes = <String>[];
    for (final fsc in fscs) {
      codes.addAll(fsc.fscCodes);
    }
    return codes;
  }
}

/// Backup Scanner Service
class BackupScannerService extends ChangeNotifier {
  // Default backup path
  static const String defaultBackupPath = 'C:/Data/Backup';

  // State
  String _backupPath = defaultBackupPath;
  bool _isScanning = false;
  String _statusMessage = 'Ready';
  double _scanProgress = 0.0;

  // Results
  final List<BackupVehicle> _vehicles = [];
  BackupVehicle? _selectedVehicle;

  // Getters
  String get backupPath => _backupPath;
  bool get isScanning => _isScanning;
  String get statusMessage => _statusMessage;
  double get scanProgress => _scanProgress;
  List<BackupVehicle> get vehicles => List.unmodifiable(_vehicles);
  BackupVehicle? get selectedVehicle => _selectedVehicle;

  /// Set backup path
  set backupPath(String path) {
    _backupPath = path;
    notifyListeners();
  }

  /// Select a vehicle
  void selectVehicle(BackupVehicle? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Scan backup folder - simplified wrapper
  Future<void> scanBackupFolder() async {
    await scanBackups();
  }

  /// Scan backup folder for vehicles
  Future<List<BackupVehicle>> scanBackups() async {
    _isScanning = true;
    _statusMessage = 'Scanning backup folder...';
    _scanProgress = 0.0;
    _vehicles.clear();
    notifyListeners();

    try {
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) {
        _statusMessage = '❌ Backup folder not found: $_backupPath';
        return [];
      }

      // Get all vehicle folders (format: SERIES_VIN)
      final vehicleFolders = await backupDir
          .list()
          .where((e) => e is Directory)
          .cast<Directory>()
          .toList();

      final total = vehicleFolders.length;
      var processed = 0;

      for (final vehicleFolder in vehicleFolders) {
        final vehicle = await _processVehicleFolder(vehicleFolder);
        if (vehicle != null) {
          _vehicles.add(vehicle);
        }

        processed++;
        _scanProgress = processed / total;
        _statusMessage = 'Processing ${processed}/${total} vehicles...';
        notifyListeners();
      }

      // Sort by series and VIN
      _vehicles.sort((a, b) {
        final seriesCompare = a.series.compareTo(b.series);
        return seriesCompare != 0 ? seriesCompare : a.vin.compareTo(b.vin);
      });

      _statusMessage = '✅ Found ${_vehicles.length} vehicle backups';
    } catch (e) {
      _statusMessage = '❌ Scan error: $e';
      debugPrint('Backup scan error: $e');
    } finally {
      _isScanning = false;
      _scanProgress = 1.0;
      notifyListeners();
    }

    return _vehicles;
  }

  /// Process a single vehicle folder
  Future<BackupVehicle?> _processVehicleFolder(Directory folder) async {
    try {
      final folderName = folder.path.split(Platform.pathSeparator).last;

      // Try multiple folder name patterns
      String? series;
      String? vin;

      // Pattern 1: SERIES_VIN (e.g., G030_WBAJA9101LGJ02193)
      var match = RegExp(
        r'^([A-Z]\d{3})_([A-Z0-9]{17})$',
      ).firstMatch(folderName);
      if (match != null) {
        series = match.group(1)!;
        vin = match.group(2)!;
      }

      // Pattern 2: SERIES-VIN with hyphen
      match ??= RegExp(r'^([A-Z]\d{3})-([A-Z0-9]{17})$').firstMatch(folderName);
      if (match != null && series == null) {
        series = match.group(1)!;
        vin = match.group(2)!;
      }

      // Pattern 3: Just VIN (try to extract series from FA later)
      match ??= RegExp(r'^([A-Z0-9]{17})$').firstMatch(folderName);
      if (match != null && series == null) {
        vin = match.group(1)!;
        series = 'UNKNOWN';
      }

      // Pattern 4: Any folder with VIN anywhere in name
      match ??= RegExp(r'([A-Z]{2}[A-Z0-9]{15})').firstMatch(folderName);
      if (match != null && series == null) {
        vin = match.group(1)!;
        // Try to extract series from folder name
        final seriesMatch = RegExp(r'([EFGIU]\d{2,3})').firstMatch(folderName);
        series = seriesMatch?.group(1) ?? 'UNKNOWN';
      }

      // Pattern 5: Folder contains underscore, split and check parts
      if (series == null && folderName.contains('_')) {
        final parts = folderName.split('_');
        for (final part in parts) {
          if (part.length == 17 && RegExp(r'^[A-Z0-9]{17}$').hasMatch(part)) {
            vin = part;
          }
          if (RegExp(r'^[EFGIU]\d{2,3}$').hasMatch(part)) {
            series = part;
          }
        }
        series ??= 'UNKNOWN';
      }

      // If still no VIN found, skip this folder
      if (vin == null) {
        debugPrint('BackupScanner: Skipping folder (no VIN): $folderName');
        return null;
      }

      debugPrint(
        'BackupScanner: Found vehicle folder: $folderName -> Series=$series, VIN=$vin',
      );

      // Find timestamp folder (most recent) or use folder directly
      Directory latestBackup;
      String backupDate;

      final subFolders = await folder
          .list()
          .where((e) => e is Directory)
          .cast<Directory>()
          .toList();

      // Check if files exist directly in folder (no timestamp subfolder)
      final directFaPath = '${folder.path}/FA.xml';
      final directSvtPath = '${folder.path}/SVT_ECU.xml';
      final hasDirectFiles =
          await File(directFaPath).exists() ||
          await File(directSvtPath).exists();

      if (hasDirectFiles || subFolders.isEmpty) {
        // Use folder directly
        latestBackup = folder;
        backupDate = 'Direct';
        debugPrint(
          'BackupScanner: Using folder directly (no timestamp subfolder)',
        );
      } else {
        // Sort by name (timestamp format ensures newest is last)
        subFolders.sort(
          (a, b) => a.path
              .split(Platform.pathSeparator)
              .last
              .compareTo(b.path.split(Platform.pathSeparator).last),
        );
        latestBackup = subFolders.last;
        backupDate = latestBackup.path.split(Platform.pathSeparator).last;
      }

      // Find files
      File? faFile;
      File? svtFile;
      File? reportFile;
      File? dtcFile;
      File? fpFile;

      // Check for FA.xml directly in backup folder
      final directFa = '${latestBackup.path}/FA.xml';
      if (await File(directFa).exists()) {
        faFile = File(directFa);
      }

      // Check for SVT_ECU.xml in root
      final svtPath = '${latestBackup.path}/SVT_ECU.xml';
      if (await File(svtPath).exists()) {
        svtFile = File(svtPath);
      }

      // Also check for SVT.xml
      if (svtFile == null) {
        final svtPath2 = '${latestBackup.path}/SVT.xml';
        if (await File(svtPath2).exists()) {
          svtFile = File(svtPath2);
        }
      }

      // Check for Report.txt
      final reportPath = '${latestBackup.path}/Report.txt';
      if (await File(reportPath).exists()) {
        reportFile = File(reportPath);
      }

      // Check for DTC file
      final dtcPath = '${latestBackup.path}/DTC_$vin.txt';
      if (await File(dtcPath).exists()) {
        dtcFile = File(dtcPath);
      }

      // Check VCM BACKUP folder (if no FA found yet)
      if (faFile == null) {
        final vcmBackupPath = '${latestBackup.path}/VCM BACKUP';
        if (await Directory(vcmBackupPath).exists()) {
          final vcmFaPath = '$vcmBackupPath/FA.xml';
          if (await File(vcmFaPath).exists()) {
            faFile = File(vcmFaPath);
          }
          final vcmFpPath = '$vcmBackupPath/FP.xml';
          if (await File(vcmFpPath).exists()) {
            fpFile = File(vcmFpPath);
          }
        }
      }

      // Check VCM MASTER folder if no FA found
      if (faFile == null) {
        final vcmMasterPath = '${latestBackup.path}/VCM MASTER';
        final masterFaPath = '$vcmMasterPath/FA.xml';
        if (await File(masterFaPath).exists()) {
          faFile = File(masterFaPath);
        }
      }

      // Parse FA for additional info
      String? iStep;
      String? vehicleName;
      List<String> saCodes = [];
      List<String> eCodes = [];
      String? typeKey;
      String? colorCode;

      if (faFile != null) {
        final faInfo = await _parseFAFile(faFile);
        iStep = faInfo['iStep'];
        vehicleName = faInfo['vehicleName'];
        saCodes = (faInfo['saCodes'] as List<String>?) ?? [];
        eCodes = (faInfo['eCodes'] as List<String>?) ?? [];
        typeKey = faInfo['typeKey'];
        colorCode = faInfo['colorCode'];
      }

      // Scan NCD folder for ECUs
      final ecus = await _scanNCDFolder('${latestBackup.path}/NCD');

      // Scan FSC folder
      final fscs = await _scanFSCFolder('${latestBackup.path}/FSC');

      return BackupVehicle(
        vin: vin,
        series: series ?? 'UNKNOWN',
        folderPath: latestBackup.path,
        backupDate: backupDate,
        iStep: iStep,
        vehicleName: vehicleName,
        faFile: faFile,
        svtFile: svtFile,
        reportFile: reportFile,
        dtcFile: dtcFile,
        fpFile: fpFile,
        ecus: ecus,
        fscs: fscs,
        saCodes: saCodes,
        eCodes: eCodes,
        typeKey: typeKey,
        colorCode: colorCode,
      );
    } catch (e) {
      debugPrint('Error processing vehicle folder: $e');
      return null;
    }
  }

  /// Parse FA file for vehicle info
  Future<Map<String, dynamic>> _parseFAFile(File file) async {
    final result = <String, dynamic>{};

    try {
      final content = await file.readAsString();
      final document = XmlDocument.parse(content);
      final root = document.rootElement;

      // Find iStep from comment
      for (final element in root.descendants.whereType<XmlElement>()) {
        if (element.name.local == 'comment') {
          final comment = element.innerText;
          final iStepMatch = RegExp(r'I-Step.*?:\s*(\S+)').firstMatch(comment);
          if (iStepMatch != null) {
            result['iStep'] = iStepMatch.group(1);
          }
        }
        if (element.name.local == 'id') {
          result['vehicleName'] = element.getAttribute('name');
        }
      }

      // Find standardFA element
      final standardFA = root.findAllElements('standardFA').firstOrNull;
      if (standardFA != null) {
        result['series'] = standardFA.getAttribute('series');
        result['typeKey'] = standardFA.getAttribute('typeKey');
        result['colorCode'] = standardFA.getAttribute('colourCode');
      }

      // Extract SA codes
      final saCodes = <String>[];
      for (final saCode in root.findAllElements('saCode')) {
        saCodes.add(saCode.innerText.trim());
      }
      result['saCodes'] = saCodes;

      // Extract E codes
      final eCodes = <String>[];
      for (final eCode in root.findAllElements('eCode')) {
        eCodes.add(eCode.innerText.trim());
      }
      result['eCodes'] = eCodes;
    } catch (e) {
      debugPrint('Error parsing FA file: $e');
    }

    return result;
  }

  /// Scan NCD folder for ECU data
  Future<List<BackupEcu>> _scanNCDFolder(String path) async {
    final ecus = <BackupEcu>[];

    try {
      final ncdDir = Directory(path);
      if (!await ncdDir.exists()) return ecus;

      await for (final entity in ncdDir.list()) {
        if (entity is Directory) {
          final folderName = entity.path.split(Platform.pathSeparator).last;

          // Parse folder name: ECU_NAME [ADDRESS]
          final match = RegExp(
            r'^(.+)\s+\[([0-9a-fA-F]+)\]$',
          ).firstMatch(folderName);
          if (match != null) {
            final ecuName = match.group(1)!;
            final address = match.group(2)!;

            // Find NCD files
            final ncdFiles = <File>[];
            await for (final file in entity.list()) {
              if (file is File && file.path.toLowerCase().endsWith('.ncd')) {
                ncdFiles.add(file);
              }
            }

            ecus.add(
              BackupEcu(
                name: ecuName,
                address: address,
                folderPath: entity.path,
                ncdFiles: ncdFiles,
              ),
            );
          }
        }
      }

      // Sort by address
      ecus.sort((a, b) => a.addressInt.compareTo(b.addressInt));
    } catch (e) {
      debugPrint('Error scanning NCD folder: $e');
    }

    return ecus;
  }

  /// Scan FSC folder
  Future<List<BackupFsc>> _scanFSCFolder(String path) async {
    final fscs = <BackupFsc>[];

    try {
      final fscDir = Directory(path);
      if (!await fscDir.exists()) return fscs;

      await for (final entity in fscDir.list()) {
        if (entity is Directory) {
          final folderName = entity.path.split(Platform.pathSeparator).last;

          // Parse folder name
          final match = RegExp(
            r'^(.+)\s+\[([0-9a-fA-F]+)\]$',
          ).firstMatch(folderName);
          if (match != null) {
            final ecuName = match.group(1)!;
            final address = match.group(2)!;

            // Find FSC files
            final fscFiles = <File>[];
            await for (final file in entity.list()) {
              if (file is File && file.path.toLowerCase().endsWith('.fsc')) {
                fscFiles.add(file);
              }
            }

            fscs.add(
              BackupFsc(
                ecuName: ecuName,
                address: address,
                folderPath: entity.path,
                fscFiles: fscFiles,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning FSC folder: $e');
    }

    return fscs;
  }

  /// Get vehicles by series
  List<BackupVehicle> getVehiclesBySeries(String series) {
    return _vehicles.where((v) => v.series == series).toList();
  }

  /// Get unique series list
  List<String> get uniqueSeries {
    return _vehicles.map((v) => v.series).toSet().toList()..sort();
  }

  /// Search vehicles by VIN or series
  List<BackupVehicle> searchVehicles(String query) {
    final q = query.toLowerCase();
    return _vehicles
        .where(
          (v) =>
              v.vin.toLowerCase().contains(q) ||
              v.series.toLowerCase().contains(q) ||
              (v.vehicleName?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  /// Export vehicle data to path
  Future<bool> exportVehicle(BackupVehicle vehicle, String targetPath) async {
    try {
      final targetDir = Directory(targetPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Copy FA
      if (vehicle.faFile != null) {
        await vehicle.faFile!.copy('$targetPath/FA.xml');
      }

      // Copy SVT
      if (vehicle.svtFile != null) {
        await vehicle.svtFile!.copy('$targetPath/SVT_ECU.xml');
      }

      // Copy NCD files
      for (final ecu in vehicle.ecus) {
        final ecuDir = Directory('$targetPath/NCD/${ecu.displayName}');
        await ecuDir.create(recursive: true);

        for (final ncd in ecu.ncdFiles) {
          final fileName = ncd.path.split(Platform.pathSeparator).last;
          await ncd.copy('${ecuDir.path}/$fileName');
        }
      }

      // Copy FSC files
      for (final fsc in vehicle.fscs) {
        final fscDir = Directory(
          '$targetPath/FSC/${fsc.ecuName} [${fsc.address}]',
        );
        await fscDir.create(recursive: true);

        for (final fscFile in fsc.fscFiles) {
          final fileName = fscFile.path.split(Platform.pathSeparator).last;
          await fscFile.copy('${fscDir.path}/$fileName');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Export error: $e');
      return false;
    }
  }

  /// Get ECU NCD files for specific ECU
  List<File> getEcuNcdFiles(BackupVehicle vehicle, String ecuName) {
    for (final ecu in vehicle.ecus) {
      if (ecu.name == ecuName) {
        return ecu.ncdFiles;
      }
    }
    return [];
  }

  /// Get ECU FSC files
  List<File> getEcuFscFiles(BackupVehicle vehicle, String ecuName) {
    for (final fsc in vehicle.fscs) {
      if (fsc.ecuName == ecuName) {
        return fsc.fscFiles;
      }
    }
    return [];
  }
}
