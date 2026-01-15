/// BMW ZGW Simulator - Complete Unified Implementation
/// Full vehicle simulation with backup loading, PSDZ matching, and real ECU responses
///
/// Features:
/// - Complete DoIP/HSFZ protocol support (ports 13400, 6801, 6811)
/// - Backup vehicle loading (FA, SVT, NCD, FSC)
/// - PSDZ data matching for authentic CAFD/SWFL files
/// - Dynamic ECU creation from SVT data
/// - Real BMW UDS responses
/// - NBT EVO full feature simulation
/// - Deep Simulation Engine integration
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library zgw_simulator_complete;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'virtual_ecu.dart';
import 'nbt_evo_ecu.dart';
import 'atm_ecu.dart';
import 'psdz_service.dart';
import 'psdz_data_loader.dart';
import 'simulation_export_service.dart';
import 'backup_scanner_service.dart';
import '../models/tal_file.dart';
import 'deep_simulation/deep_simulation.dart';

/// Streaming vehicle info for simulation
class StreamingVehicle {
  final String vin;
  final String series;
  final String? iStep;
  final String source; // 'backup', 'matched', 'manual'
  final FAData? faData;
  final SVTData? svtData;
  final List<StreamingEcu> ecus;
  final Map<String, String> metadata;

  StreamingVehicle({
    required this.vin,
    required this.series,
    this.iStep,
    required this.source,
    this.faData,
    this.svtData,
    this.ecus = const [],
    this.metadata = const {},
  });

  String get displayName {
    final parts = [series, vin.substring(vin.length - 7)];
    if (iStep != null) parts.add(iStep!);
    return parts.join(' - ');
  }

  int get ecuCount => ecus.length;
  int get ncdCount => ecus.fold(0, (sum, e) => sum + e.ncdFiles.length);
  bool get isComplete => faData != null && svtData != null;
}

/// Streaming ECU data
class StreamingEcu {
  final String name;
  final int address;
  final List<String> sgbmIds;
  final List<File> ncdFiles;
  final List<File> cafdFiles;
  final String? variantCoding;
  bool isPsdzMatched;

  StreamingEcu({
    required this.name,
    required this.address,
    this.sgbmIds = const [],
    this.ncdFiles = const [],
    this.cafdFiles = const [],
    this.variantCoding,
    this.isPsdzMatched = false,
  });

  String get displayName =>
      '$name [0x${address.toRadixString(16).toUpperCase()}]';
}

/// ZGW Simulator Complete - Unified Service
class ZGWSimulatorComplete extends ChangeNotifier {
  // Network configuration
  static const int doipPort = 13400;
  static const int hsfzPort = 6801;
  static const int hsfzDataPort = 6811;
  static const int discoveryPort = 13400;
  static const int doipVersion = 0x02;
  static const int doipInverseVersion = 0xFD;

  // State
  bool _isRunning = false;
  bool _isLoading = false;
  bool _routingActivated = false;
  String _statusMessage = 'Ready';

  // Current streaming vehicle
  StreamingVehicle? _streamingVehicle;

  // ECUs map - diagAddress -> VirtualECU
  final Map<int, VirtualECU> _ecus = {};

  // ZGW ECU (main gateway)
  VirtualECU? _zgwEcu;

  // NBT EVO ECU (full implementation)
  NbtEvoEcu? _nbtEvoEcu;

  // Deep Simulation Engine
  DeepSimulationEngine? _deepSimulation;
  bool _useDeepSimulation = false;

  // Services
  final BackupScannerService _backupScanner = BackupScannerService();
  final SimulationExportService _exportService = SimulationExportService();
  PsdzDataLoaderService? _psdzLoader;
  SvtPsdzMatcher? _psdzMatcher;

  // Paths
  String _psdzDataPath = 'C:/Data/psdzdata';
  String _backupPath = 'C:/Data/Backup';

  // Logging
  final List<LogEntry> _logs = [];

  // Build info (helps ensure we test the right executable)
  String? _buildInfo;
  bool _buildInfoLoaded = false;

  String? get buildInfo => _buildInfo;

  /// Exposed so UI can show version/build even before starting servers.
  Future<void> ensureBuildInfoLoaded() => _loadBuildInfoOnce();

  // Network components
  RawDatagramSocket? _udpSocket;
  ServerSocket? _doipServer;
  ServerSocket? _hsfzServer;
  ServerSocket? _hsfzDataServer;

  // Prevent parallel start/stop calls (e.g. double tap on Start).
  Future<bool>? _startInFlight;
  Future<void>? _stopInFlight;

  // TCP stream reassembly buffers (TCP can split or coalesce frames)
  final Map<Socket, List<int>> _hsfzRxBuffers = {};
  final Map<Socket, List<int>> _doipRxBuffers = {};

  static const int _maxHsfzPayloadLen = 1024 * 1024; // 1MB safety cap
  static const int _maxDoipPayloadLen = 1024 * 1024; // 1MB safety cap
  final List<Socket> _connectedClients = [];

  // DoIP state
  int _testerAddress = 0x0F0D;
  int _logicalAddress = 0x1010;

  // Statistics
  int _totalRequests = 0;
  int _totalResponses = 0;
  int _totalErrors = 0;
  final Map<int, int> _ecuRequestCounts = {};

  // Getters
  bool get isRunning => _isRunning;
  bool get isLoading => _isLoading;
  bool get routingActivated => _routingActivated;
  String get statusMessage => _statusMessage;
  StreamingVehicle? get streamingVehicle => _streamingVehicle;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  List<int> get ecuAddresses => _ecus.keys.toList()..sort();
  int get connectedClients => _connectedClients.length;
  int get totalRequests => _totalRequests;
  int get totalResponses => _totalResponses;
  NbtEvoEcu? get nbtEvo => _nbtEvoEcu;

  String get vin => _zgwEcu?.vin ?? 'WBA00000000000000';
  String get iStep => _zgwEcu?.iStep ?? 'G030-23-07-550';

  String get psdzDataPath => _psdzDataPath;
  set psdzDataPath(String value) {
    _psdzDataPath = value;
    notifyListeners();
  }

  String get backupPath => _backupPath;
  set backupPath(String value) {
    _backupPath = value;
    _backupScanner.backupPath = value;
    notifyListeners();
  }

  // Backup scanner access
  BackupScannerService get backupScanner => _backupScanner;
  List<BackupVehicle> get backupVehicles => _backupScanner.vehicles;

  // PSDZ loader access
  PsdzDataLoaderService? get psdzLoader => _psdzLoader;

  // Deep Simulation access
  DeepSimulationEngine? get deepSimulation => _deepSimulation;
  bool get useDeepSimulation => _useDeepSimulation;
  set useDeepSimulation(bool value) {
    _useDeepSimulation = value;
    notifyListeners();
  }

  ZGWSimulatorComplete() {
    _initDefaultEcus();
    _initDeepSimulation();
  }

  /// Export current simulation state
  Future<String> exportCurrentState(String targetPath) async {
    _log('SYS', '📦 Exporting simulation state to $targetPath...');
    try {
      final path = await _exportService.exportSimulation(
        exportPath: targetPath,
        ecus: _ecus.values.toList(),
        fa: _zgwEcu?.faData,
        svt: _zgwEcu?.svtData,
        vin: vin,
      );
      _log('SYS', '✅ Export completed: $path');
      return path;
    } catch (e) {
      _log('SYS', '❌ Export failed: $e');
      rethrow;
    }
  }

  /// Apply BMW job definitions (from external reference lists) to gateway-like ECUs.
  ///
  /// Goal: match ISTA/E-Sys expectations for common ZGW/VCM jobs without globally
  /// changing all ECUs (avoids DID conflicts such as 0xF100 and 0x2501).
  void _installGatewayJobDefs(VirtualECU ecu) {
    // Session-related state.
    ecu.udsSession['energyMode'] ??=
        0x00; // 0=default, 1=production, 2=transport, 3=flash
    ecu.udsSession['extendedMode'] ??= 0x00;
    ecu.udsSession['roeActive'] ??= false;

    int _currentSessionType() {
      final f186 = ecu.getDID(0xF186);
      if (f186 != null && f186.isNotEmpty) return f186[0];
      return 0x01;
    }

    Uint8List _u8(List<int> bytes) => Uint8List.fromList(bytes);

    // --- DIDs (0x22) from jobdef.txt ---

    // ReadActiveSessionState; 22 F1 00  (DID 0xF100)
    // In our VirtualECU default, 0xF100 is used for VIN+I-Step; override only on gateway.
    ecu.mapping.registerDid(0xF100, (e, did, req) {
      return _u8([_currentSessionType()]);
    });

    // ReadActiveDiagnosticSession; 22 F1 86  (DID 0xF186)
    ecu.mapping.registerDid(0xF186, (e, did, req) {
      return _u8([_currentSessionType()]);
    });

    // ReadEnergyMode; 22 10 0A (DID 0x100A)
    ecu.mapping.registerDid(0x100A, (e, did, req) {
      final v = (ecu.udsSession['energyMode'] as int?) ?? 0x00;
      return _u8([v & 0xFF]);
    });

    // ReadExtendedMode; 22 10 0E (DID 0x100E)
    ecu.mapping.registerDid(0x100E, (e, did, req) {
      final v = (ecu.udsSession['extendedMode'] as int?) ?? 0x00;
      return _u8([v & 0xFF]);
    });

    // ReadStatusLifeCycle; 22 17 35 (DID 0x1735)
    ecu.mapping.registerDid(0x1735, (e, did, req) {
      // 0x00 is commonly treated as "OK / production" in many captures.
      return _u8([0x00]);
    });

    // ReadIPConfig; 22 17 2A (DID 0x172A)
    ecu.mapping.registerDid(0x172A, (e, did, req) {
      // Keep default payload if present (VirtualECU provides a non-empty dummy).
      final v = ecu.getDID(0x172A);
      if (v != null && v.isNotEmpty) return v;
      // Fallback: status(0x00) + link-local placeholder.
      return _u8([
        0x00,
        0xA9,
        0xFE,
        0x00,
        0x01,
        0xFF,
        0xFF,
        0x00,
        0,
        0,
        0,
        0,
        0,
      ]);
    });

    // ReadSVKBak1; 22 F1 04 (DID 0xF104)
    ecu.mapping.registerDid(0xF104, (e, did, req) {
      final v = ecu.getDID(0xF101) ?? ecu.getDID(0xF150);
      if (v != null && v.isNotEmpty) return v;
      return _u8([0x01, 0x00]);
    });

    // ReadMemorySegmentationTable; 22 25 01 (DID 0x2501)
    // NOTE: VirtualECU default uses 0x2501 for "engine temperature" which is not
    // suitable on ZGW jobs. Provide a minimal synthetic table.
    ecu.mapping.registerDid(0x2501, (e, did, req) {
      // Very small placeholder segmentation table:
      // [count=1][start=0x00000000][len=0x00100000][attr=0x00]
      return _u8([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00]);
    });

    // ReadMemoryAddress; 22 25 06 (DID 0x2506)
    ecu.mapping.registerDid(0x2506, (e, did, req) {
      // Placeholder: 4 bytes address = 0.
      return _u8([0x00, 0x00, 0x00, 0x00]);
    });

    // --- Routines (0x31) from jobdef.txt ---
    ecu.mapping.registerRoutine(0x0F0C, (e, sub, rid, data, req) {
      // SetEnergyModeDefault/Flash/Production/Transport
      final mode = data.isNotEmpty ? (data[0] & 0xFF) : 0x00;
      ecu.udsSession['energyMode'] = mode;
      return _u8([0x71, sub, 0x0F, 0x0C, mode]);
    });

    ecu.mapping.registerRoutine(0x1003, (e, sub, rid, data, req) {
      // SetExtendedModeFlash; 31 01 10 03 01
      final v = data.isNotEmpty ? (data[0] & 0xFF) : 0x01;
      ecu.udsSession['extendedMode'] = v;
      return _u8([0x71, sub, 0x10, 0x03, v]);
    });

    ecu.mapping.registerRoutine(0x100E, (e, sub, rid, data, req) {
      // ActivateParallelFlashMode; 31 01 10 0E
      ecu.udsSession['extendedMode'] = 0x03;
      return _u8([0x71, sub, 0x10, 0x0E, 0x00]);
    });

    ecu.mapping.registerRoutine(0x100F, (e, sub, rid, data, req) {
      // ActivateNormalFlashMode; 31 01 10 0F
      ecu.udsSession['extendedMode'] = 0x00;
      return _u8([0x71, sub, 0x10, 0x0F, 0x00]);
    });

    ecu.mapping.registerRoutine(0x1010, (e, sub, rid, data, req) {
      // SetDefaultBusDeactivate/Activate; 31 01 10 10 00/01
      final v = data.isNotEmpty ? (data[0] & 0xFF) : 0x00;
      ecu.udsSession['busDefaultActive'] = (v == 0x01);
      return _u8([0x71, sub, 0x10, 0x10, v]);
    });

    ecu.mapping.registerRoutine(0x1011, (e, sub, rid, data, req) {
      // GetActualConfig; 31 01 10 11
      final bus =
          ((ecu.udsSession['busDefaultActive'] as bool?) ?? true) ? 0x01 : 0x00;
      return _u8([0x71, sub, 0x10, 0x11, bus]);
    });

    ecu.mapping.registerRoutine(0x0F06, (e, sub, rid, data, req) {
      // InfoSpeicherLoeschen; 31 01 0F 06
      return _u8([0x71, sub, 0x0F, 0x06, 0x00]);
    });

    ecu.mapping.registerRoutine(0x0F0B, (e, sub, rid, data, req) {
      // ActivateROE/DeactivateROE; 31 01 0F 0B ...
      // We don't implement a full ROE engine; acknowledge and track a bool.
      final isActivate = data.contains(
        0x45,
      ); // heuristic: 0x45 in provided sample
      ecu.udsSession['roeActive'] = isActivate;
      // Echo minimal status + a couple of bytes from request for better realism.
      final tail = data.length >= 2 ? data.sublist(data.length - 2) : <int>[];
      return _u8([0x71, sub, 0x0F, 0x0B, isActivate ? 0x01 : 0x00, ...tail]);
    });

    ecu.mapping.registerRoutine(0xFF01, (e, sub, rid, data, req) {
      // CheckProgDeps; 31 01 FF 01
      return _u8([0x71, sub, 0xFF, 0x01, 0x00]);
    });

    ecu.mapping.registerRoutine(0x0203, (e, sub, rid, data, req) {
      // CheckProgPreCond; 31 01 02 03
      return _u8([0x71, sub, 0x02, 0x03, 0x00]);
    });

    ecu.mapping.registerRoutine(0xF760, (e, sub, rid, data, req) {
      // ResetHUAktivierungsLeitung; 31 01 F7 60
      return _u8([0x71, sub, 0xF7, 0x60, 0x00]);
    });
  }

  /// Initialize default ECUs
  void _initDefaultEcus() {
    // ZGW - Central Gateway
    _zgwEcu = VirtualECU(diagAddress: 0x10, name: 'ZGW');
    _ecus[0x10] = _zgwEcu!;

    // Install job definitions expected by ISTA/E-Sys for gateway/VCM workflows.
    _installGatewayJobDefs(_zgwEcu!);

    // Set default data for E-Sys compatibility
    _initDefaultVehicleData();

    // NBT EVO - Head Unit (full implementation)
    // Default to NBT2 identity unless the loaded SVT says otherwise.
    _nbtEvoEcu = NbtEvoFactory.createFullFeatured(psdzPath: _psdzDataPath);
    _ecus[0x63] = _nbtEvoEcu!;

    // ATM - Telematics (Specialized implementation)
    // Prevents "ATM not present" errors by providing valid signal/status data.
    _ecus[0x61] = AtmEcu();

    // Common ECUs
    _addDefaultEcus();

    _log('SYS', 'Initialized with ${_ecus.length} default ECUs');
  }

  /// Initialize default vehicle data for E-Sys
  void _initDefaultVehicleData() {
    // Default FA for E-Sys (will be overwritten when loading backup)
    final defaultFA = FAData();
    defaultFA.vin = 'WBAJA9101LGJ02193';
    defaultFA.typeKey = 'JA91';
    defaultFA.series = 'G30';
    defaultFA.productionDate = DateTime(2019, 7, 15);
    defaultFA.saCodes = [
      'S248A',
      'S2VBA',
      'S403A',
      'S4URA',
      'S5DFA',
      'S6AKA',
      'S6NVA',
    ];
    defaultFA.eCodes = ['E001', 'E002'];
    defaultFA.hoCodes = ['HO001', 'HO002'];

    // Default I-Step
    const defaultIStep = 'G030-23-07-550';

    // Inject into ZGW ECU
    _zgwEcu!.loadFA(defaultFA);
    _zgwEcu!.vin = defaultFA.vin;
    _zgwEcu!.iStep = defaultIStep;

    // Set essential DIDs manually for E-Sys VCM access
    _zgwEcu!.setDID(0xF190, Uint8List.fromList(defaultFA.vin.codeUnits));
    _zgwEcu!.setDID(
      0x2503,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );
    _zgwEcu!.setDID(
      0x2504,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );
    _zgwEcu!.setDID(
      0x2505,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );
    _zgwEcu!.setDID(
      0x3F06,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );
    _zgwEcu!.setDID(
      0x100B,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );
    _zgwEcu!.setDID(
      0x100C,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );
    _zgwEcu!.setDID(
      0x100D,
      Uint8List.fromList(
        defaultIStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );

    // VCM Status DIDs
    _zgwEcu!.setDID(
      0xF1D0,
      Uint8List.fromList([0x01]),
    ); // VCM Status: FA stored
    _zgwEcu!.setDID(0xF1D1, Uint8List.fromList([0x01])); // VCM Backup exists
    _zgwEcu!.setDID(0xF1D2, Uint8List.fromList([0x01])); // VCM Master exists

    _log(
      'VCM',
      '✅ Default VCM data initialized: VIN=${defaultFA.vin}, I-Step=$defaultIStep',
    );
  }

  void _addDefaultEcus() {
    final defaultEcus = {
      0x01: 'BDC', // Body Domain Controller (VCM Backup Partner)
      0x12: 'DME', // Engine
      0x18: 'EGS', // Transmission
      0x2A: 'DSC', // Stability Control
      0x30: 'EPS', // Electric Power Steering
      0x40: 'CAS', // Car Access System (VCM Master Partner)
      0x60: 'KOMBI', // Instrument Cluster
      0x72: 'FEM', // Front Electronic Module
      0xB0: 'FRM', // Footwell Module
      0xA0: 'JBBF', // Junction Box Front
      0x6C: 'IHKA', // Climate Control
      0x71: 'SZL', // Steering Column Switch
    };

    for (var entry in defaultEcus.entries) {
      if (!_ecus.containsKey(entry.key)) {
        final ecu = VirtualECU(diagAddress: entry.key, name: entry.value);

        // Copy VCM data to BDC (VCM Backup) and CAS (VCM Master)
        if (entry.key == 0x01 || entry.key == 0x40) {
          if (_zgwEcu != null) {
            if (_zgwEcu!.faData != null) ecu.loadFA(_zgwEcu!.faData!);
            ecu.vin = _zgwEcu!.vin;
            ecu.iStep = _zgwEcu!.iStep;

            // Copy essential DIDs
            for (final did in [
              0xF190,
              0x1769,
              0x3FD0,
              0x2503,
              0x2504,
              0x2505,
              0x3F06,
              0x100B,
              0x100C,
              0x100D,
              0xF1D0,
              0xF1D1,
              0xF1D2,
            ]) {
              final data = _zgwEcu!.getDID(did);
              if (data != null) ecu.setDID(did, data);
            }
          }
        }

        _ecus[entry.key] = ecu;
      }
    }

    // Add functional addresses that route to ZGW
    // 0xDF is the functional address for all ECUs (broadcast)
    // E-Sys often uses this for initial VCM queries
    if (!_ecus.containsKey(0xDF) && _zgwEcu != null) {
      _ecus[0xDF] = _zgwEcu!; // Route functional address to ZGW
    }
  }

  void _initDeepSimulation() {
    _deepSimulation = DeepSimulationEngine(
      psdzPath: _psdzDataPath,
      backupPath: _backupPath,
    );

    // Listen to deep simulation updates
    _deepSimulation!.addListener(() {
      notifyListeners();
    });

    // Initialize async
    _deepSimulation!.initialize().then((_) {
      _log('DEEP', 'Initialized Deep Simulation Engine');
    });
  }

  // ============================================================
  // Backup Vehicle Loading
  // ============================================================

  /// Scan backup folder for vehicles
  Future<List<BackupVehicle>> scanBackups() async {
    _isLoading = true;
    _statusMessage = 'Scanning backup folder...';
    notifyListeners();

    try {
      await _backupScanner.scanBackups();
      _log('SCAN', 'Found ${_backupScanner.vehicles.length} backup vehicles');
      _statusMessage = 'Found ${_backupScanner.vehicles.length} vehicles';
    } catch (e) {
      _log('ERR', 'Backup scan error: $e');
      _statusMessage = 'Scan error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _backupScanner.vehicles;
  }

  /// Load vehicle from backup for streaming
  Future<void> loadBackupVehicle(BackupVehicle backup) async {
    _isLoading = true;
    _statusMessage = 'Loading backup vehicle...';
    notifyListeners();

    try {
      // Parse FA
      FAData? faData;
      if (backup.faFile != null) {
        faData = FAData();
        final content = await backup.faFile!.readAsString();
        faData.loadFromXml(content);
        _log('FA', 'Loaded FA: ${backup.vin}');
      }

      // Parse SVT
      SVTData? svtData;
      if (backup.svtFile != null) {
        svtData = SVTData();
        final content = await backup.svtFile!.readAsString();
        svtData.loadFromXml(content);
        _log('SVT', 'Loaded SVT: ${svtData.ecus.length} ECUs');
      }

      // Create streaming ECUs from backup
      final streamingEcus = <StreamingEcu>[];
      for (final backupEcu in backup.ecus) {
        final sgbmIds = <String>[];

        // Get SGBM IDs from NCD file names
        for (final ncd in backupEcu.ncdFiles) {
          final name = ncd.path.split(Platform.pathSeparator).last;
          final sgbmMatch = RegExp(
            r'([A-Z]+_[A-Z0-9]+_\d+_\d+_\d+)',
          ).firstMatch(name);
          if (sgbmMatch != null) {
            sgbmIds.add(sgbmMatch.group(1)!);
          }
        }

        streamingEcus.add(
          StreamingEcu(
            name: backupEcu.name,
            address: backupEcu.addressInt,
            sgbmIds: sgbmIds,
            ncdFiles: backupEcu.ncdFiles,
            variantCoding: backupEcu.variantCoding,
          ),
        );
      }

      // Create streaming vehicle
      _streamingVehicle = StreamingVehicle(
        vin: backup.vin,
        series: backup.series,
        iStep: backup.iStep,
        source: 'backup',
        faData: faData,
        svtData: svtData,
        ecus: streamingEcus,
        metadata: {
          'backupDate': backup.backupDate,
          'folderPath': backup.folderPath,
          if (backup.typeKey != null) 'typeKey': backup.typeKey!,
        },
      );

      // Inject into ECUs
      await _injectVehicleIntoEcus();

      _statusMessage = 'Vehicle loaded: ${backup.displayName}';
      _log('VEH', 'Streaming: ${_streamingVehicle!.displayName}');
    } catch (e) {
      _log('ERR', 'Load error: $e');
      _statusMessage = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load matched vehicle (from PSDZ scanner)
  Future<void> loadMatchedVehicle(MatchedVehicle matched) async {
    _isLoading = true;
    _statusMessage = 'Loading matched vehicle...';
    notifyListeners();

    try {
      // Parse FA
      FAData? faData;
      if (matched.faFile != null) {
        faData = FAData();
        final content = await File(matched.faFile!.path).readAsString();
        faData.loadFromXml(content);
      }

      // Parse SVT
      SVTData? svtData;
      if (matched.svtFile != null) {
        svtData = SVTData();
        final content = await File(matched.svtFile!.path).readAsString();
        svtData.loadFromXml(content);
      }

      // Create streaming ECUs from SVT
      final streamingEcus = <StreamingEcu>[];
      if (svtData != null) {
        for (final svtEcu in svtData.ecus) {
          final sgbmIds = svtEcu.parts
              .map((p) => p.sgbmId ?? '')
              .where((s) => s.isNotEmpty)
              .toList();

          streamingEcus.add(
            StreamingEcu(
              name: svtEcu.name,
              address: svtEcu.address,
              sgbmIds: sgbmIds,
            ),
          );
        }
      }

      // Create streaming vehicle
      _streamingVehicle = StreamingVehicle(
        vin: matched.vin,
        series: matched.series ?? '',
        iStep: matched.svtFile?.istep,
        source: 'matched',
        faData: faData,
        svtData: svtData,
        ecus: streamingEcus,
      );

      // Inject into ECUs
      await _injectVehicleIntoEcus();

      _statusMessage = 'Vehicle loaded: ${matched.displayName}';
      _log('VEH', 'Streaming: ${_streamingVehicle!.displayName}');
    } catch (e) {
      _log('ERR', 'Load error: $e');
      _statusMessage = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Inject loaded vehicle data into all ECUs
  Future<void> _injectVehicleIntoEcus() async {
    if (_streamingVehicle == null) return;

    final vehicle = _streamingVehicle!;

    // Set I-Step - use vehicle iStep or derive from series
    String effectiveIStep =
        vehicle.iStep ?? _deriveIStepFromSeries(vehicle.series);

    // Inject FA data FIRST (sets DIDs in existing ECUs)
    if (vehicle.faData != null) {
      final faBinary = vehicle.faData!.toBinaryVCM();
      _log(
        'VCM',
        '📌 FA loaded: VIN=${vehicle.faData!.vin}, Size=${faBinary.length} bytes',
      );
      for (var ecu in _ecus.values) {
        ecu.loadFA(vehicle.faData!);
      }
      _log('FA', 'FA injected into ${_ecus.length} ECUs');
    } else {
      _log('VCM', '⚠️ No FA data in vehicle - using default');
    }

    // Inject SVT data
    if (vehicle.svtData != null) {
      for (var ecu in _ecus.values) {
        ecu.loadSVT(vehicle.svtData!);
      }
      _log('SVT', 'SVT injected into ${_ecus.length} ECUs');
    }

    // Create ECUs from streaming ECU list
    for (final streamEcu in vehicle.ecus) {
      // Special handling for HU (0x63): keep it as NbtEvoEcu but match SVT variant name.
      if (streamEcu.address == 0x63) {
        final desiredVariant = NbtEvoEcu.normalizeVariantName(streamEcu.name);
        final current = _ecus[0x63];
        if (current is NbtEvoEcu) {
          // If name mismatches, replace the instance so VirtualECU.name matches SVT.
          if (current.name != desiredVariant) {
            final replacement = NbtEvoEcu(
              diagAddress: 0x63,
              name: desiredVariant,
              variantName: desiredVariant,
              psdzDataPath: _psdzDataPath,
            );
            // Preserve common HU toggles.
            replacement.setVideoInMotion(true);
            replacement.setDeveloperMenu(true);

            // Carry over current vehicle context (VIN/FA/SVT) if already available.
            replacement.vin = current.vin;
            replacement.iStep = current.iStep;
            if (vehicle.faData != null) replacement.loadFA(vehicle.faData!);
            if (vehicle.svtData != null) replacement.loadSVT(vehicle.svtData!);

            _nbtEvoEcu = replacement;
            _ecus[0x63] = replacement;
            _log('HU', '🔁 Replaced HU ECU 0x63 with variant: $desiredVariant');
          }
        } else {
          // If something else is mapped to 0x63 (unlikely), force NbtEvoEcu.
          final replacement = NbtEvoEcu(
            diagAddress: 0x63,
            name: desiredVariant,
            variantName: desiredVariant,
            psdzDataPath: _psdzDataPath,
          );
          replacement.setVideoInMotion(true);
          replacement.setDeveloperMenu(true);
          if (vehicle.faData != null) replacement.loadFA(vehicle.faData!);
          if (vehicle.svtData != null) replacement.loadSVT(vehicle.svtData!);
          _nbtEvoEcu = replacement;
          _ecus[0x63] = replacement;
          _log('HU', '✅ Installed HU ECU 0x63 variant: $desiredVariant');
        }
        // Do not create a generic ECU for 0x63 below.
        continue;
      }

      if (streamEcu.address > 0 && !_ecus.containsKey(streamEcu.address)) {
        final newEcu = VirtualECU(
          diagAddress: streamEcu.address,
          name: streamEcu.name,
        );
        newEcu.vin = vehicle.vin;
        if (vehicle.faData != null) newEcu.loadFA(vehicle.faData!);
        if (vehicle.svtData != null) newEcu.loadSVT(vehicle.svtData!);

        _ecus[streamEcu.address] = newEcu;
      }

      // Load NCD files into ECU
      final ecu = _ecus[streamEcu.address];
      if (ecu != null) {
        // Fallback: build SVK parts from SGBM IDs (from NCD filenames) if present.
        // This helps ISTA even when SVT_ECU.xml does not contain full partIdentification blocks.
        if (streamEcu.sgbmIds.isNotEmpty) {
          for (final sgbmId in streamEcu.sgbmIds) {
            final part = ECUPart.fromSgbmId(sgbmId);
            if (part != null) {
              final key = (part.sgbmId ?? sgbmId).toUpperCase();
              final exists = ecu.parts.any(
                (p) => (p.sgbmId ?? '').toUpperCase() == key,
              );
              if (!exists) ecu.addPart(part);
            }
          }
        }

        for (final ncdFile in streamEcu.ncdFiles) {
          await _loadNcdIntoEcu(ecu, ncdFile);
        }

        // Set variant coding if available
        if (streamEcu.variantCoding != null) {
          ecu.setDID(
            0x1000,
            Uint8List.fromList(streamEcu.variantCoding!.codeUnits),
          );
        }
      }
    }

    // AFTER all ECUs created - set VIN and I-Step for ALL ECUs
    _setVinForAllEcus(vehicle.vin);
    _setIStepForAllEcus(effectiveIStep);
    _log(
      'VCM',
      '📌 VIN=${vehicle.vin}, I-Step=$effectiveIStep applied to ${_ecus.length} ECUs',
    );

    _log('ECU', 'Total ECUs: ${_ecus.length}');
  }

  /// Load NCD file into ECU
  Future<void> _loadNcdIntoEcu(VirtualECU ecu, File ncdFile) async {
    try {
      final content = await ncdFile.readAsBytes();
      if (content.length >= 4) {
        // NCD contains coding data - load into DID 0x1000+
        final codingData = content.length > 256
            ? content.sublist(0, 256)
            : Uint8List.fromList(content);
        ecu.loadCAFDData(0x1000, codingData);
      }
    } catch (e) {
      debugPrint('NCD load error: $e');
    }
  }

  void _setVinForAllEcus(String vin) {
    if (vin.length != 17) return;
    final vinBytes = Uint8List.fromList(
      vin.padRight(17).codeUnits.take(17).toList(),
    );

    for (final ecu in _ecus.values) {
      ecu.vin = vin;
      ecu.setDID(0xF190, vinBytes);
    }
  }

  void _setIStepForAllEcus(String istep) {
    // Use null padding (\x00) not space - E-Sys expects this!
    final istepBytes = Uint8List.fromList(
      istep.padRight(24, '\x00').codeUnits.take(24).toList(),
    );

    _log(
      'VCM',
      '🔧 Setting I-Step: $istep → ${istepBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );

    for (var ecu in _ecus.values) {
      ecu.iStep = istep;
      ecu.setDID(0x2503, istepBytes);
      ecu.setDID(0x2504, istepBytes);
      ecu.setDID(0x2505, istepBytes);
      ecu.setDID(0x3F06, istepBytes);
      ecu.setDID(0x100B, istepBytes);
      ecu.setDID(0x100C, istepBytes);
      ecu.setDID(0x100D, istepBytes);
    }
  }

  /// Derive I-Step from series name when not available
  String _deriveIStepFromSeries(String series) {
    // Common BMW series to I-Step mapping
    // Format: Sxxx-YY-MM-VVV where xxx=series, YY=year, MM=month, VVV=version
    final seriesUpper = series.toUpperCase().replaceAll(' ', '');

    // Extract series code (G11, G20, F30, etc.)
    String seriesCode = seriesUpper;
    if (seriesUpper.length >= 3) {
      seriesCode = seriesUpper.substring(0, 4).padRight(4, '0');
    } else if (seriesUpper.length >= 2) {
      seriesCode = '${seriesUpper}0'.padRight(4, '0');
    }

    // Default to current year/month and version 550
    final now = DateTime.now();
    final year = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');

    return '$seriesCode-$year-$month-550';
  }

  // ============================================================
  // PSDZ Data Matching & Loading
  // ============================================================

  /// Initialize PSDZ loader and index files
  Future<void> initPsdzLoader() async {
    _psdzLoader ??= PsdzDataLoaderService();
    _psdzLoader!.psdzPath = _psdzDataPath;

    _isLoading = true;
    _statusMessage = 'Indexing PSDZ data...';
    notifyListeners();

    try {
      await _psdzLoader!.indexFiles();
      _psdzMatcher = SvtPsdzMatcher(_psdzLoader!);
      _log('PSDZ', 'Indexed ${_psdzLoader!.totalFiles} files');
      _statusMessage = 'PSDZ: ${_psdzLoader!.totalFiles} files indexed';
    } catch (e) {
      _log('ERR', 'PSDZ index error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Match streaming vehicle ECUs with PSDZ data
  Future<Map<String, dynamic>> matchVehicleWithPsdz() async {
    if (_streamingVehicle == null || _psdzLoader == null) {
      return {'matched': 0, 'total': 0, 'missing': []};
    }

    if (!_psdzLoader!.isIndexed) {
      await initPsdzLoader();
    }

    _isLoading = true;
    _statusMessage = 'Matching with PSDZ...';
    notifyListeners();

    int matched = 0;
    int total = 0;
    final missing = <String>[];

    try {
      for (var streamEcu in _streamingVehicle!.ecus) {
        for (var sgbmId in streamEcu.sgbmIds) {
          total++;
          final psdzFile = _psdzLoader!.findFile(sgbmId);
          if (psdzFile != null) {
            matched++;
            streamEcu.isPsdzMatched = true;

            // Load CAFD content into ECU
            final ecu = _ecus[streamEcu.address];
            if (ecu != null) {
              final content = await psdzFile.load();
              if (content != null && content.isNotEmpty) {
                ecu.loadCAFDData(
                  0x1000,
                  content.sublist(0, content.length.clamp(0, 256)),
                );
              }
            }
          } else {
            missing.add(sgbmId);
          }
        }
      }

      final matchRate =
          total > 0 ? (matched / total * 100).toStringAsFixed(1) : '0';
      _log('PSDZ', 'Matched $matched/$total ($matchRate%)');
      _statusMessage = 'Matched: $matched/$total files';
    } catch (e) {
      _log('ERR', 'Match error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return {
      'matched': matched,
      'total': total,
      'missing': missing,
      'matchRate': total > 0 ? matched / total * 100 : 0.0,
    };
  }

  /// Load PSDZ data for specific ECU
  Future<void> loadPsdzForEcu(int address, String ecuName) async {
    if (_psdzLoader == null) return;

    final cafdFiles = _psdzLoader!.findCafdForEcu(ecuName);
    final ecu = _ecus[address];

    if (ecu == null || cafdFiles.isEmpty) return;

    for (var cafd in cafdFiles) {
      final content = await cafd.load();
      if (content != null && content.isNotEmpty) {
        ecu.loadCAFDData(
          0x1000,
          content.sublist(0, content.length.clamp(0, 256)),
        );
        _log('CAFD', 'Loaded ${cafd.sgbmId} for $ecuName');
        break;
      }
    }
  }

  // ============================================================
  // Simulator Control
  // ============================================================

  /// Start the simulator
  Future<bool> start() async {
    if (_isRunning) return true;

    // If a start is already running, await it.
    final inflight = _startInFlight;
    if (inflight != null) return inflight;

    final startFuture = _startInternal();
    _startInFlight = startFuture;
    try {
      return await startFuture;
    } finally {
      _startInFlight = null;
    }
  }

  Future<bool> _startInternal() async {
    try {
      await _loadBuildInfoOnce();
      _log('SYS', 'Starting simulator...');

      // On Windows it's easy to accidentally run multiple app instances.
      // If something already LISTENs on 13400/TCP, DoIP bind will fail.
      // Do not abort the whole start: allow HSFZ-only operation.
      final portBusy = await _isTcpPortInUse(doipPort);
      if (portBusy) {
        _log(
          'ERR',
          'Port $doipPort/TCP is already in use. DoIP TCP will be disabled for this run (HSFZ will still work).',
        );
      }

      // Start UDP discovery
      await _startUdpServer();

      // Start DoIP TCP server
      if (!portBusy) {
        try {
          await _startDoIPServer();
        } catch (e) {
          // Keep simulator running in HSFZ-only mode.
          _log('ERR', 'DoIP TCP server failed to start: $e');
        }
      }

      // Start HSFZ TCP servers
      await _startHSFZServers();

      // Start Deep Simulation
      if (_deepSimulation != null) {
        _deepSimulation!.start();
      }

      _isRunning = true;
      _statusMessage = portBusy
          ? 'Simulator running (HSFZ mode; DoIP TCP unavailable on $doipPort)'
          : 'Simulator running';

      _log(
        'SYS',
        portBusy
            ? '✅ Started (HSFZ ports $hsfzPort, $hsfzDataPort; DoIP TCP $doipPort busy)'
            : '✅ Started on ports $doipPort, $hsfzPort, $hsfzDataPort',
      );

      // Start announcements
      _sendAnnouncements();

      notifyListeners();
      return true;
    } catch (e) {
      _log('ERR', 'Start error: $e');
      _statusMessage = 'Error: $e';
      await stop();
      return false;
    }
  }

  Future<bool> _isTcpPortInUse(int port) async {
    try {
      final sock = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 250),
      );
      await sock.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadBuildInfoOnce() async {
    if (_buildInfoLoaded) return;
    _buildInfoLoaded = true;

    try {
      // PackageInfo replaced with static info
      final mode =
          kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug');
      _buildInfo = 'AQ///PSDZ 1.0.0 ($mode)';
      _log('SYS', 'Build: $_buildInfo');
      // Expose to UI
      notifyListeners();
    } catch (e) {
      _buildInfo = null;
      _log('SYS', 'Build info unavailable: $e');
    }
  }

  /// Stop the simulator
  Future<void> stop() async {
    final inflight = _stopInFlight;
    if (inflight != null) return inflight;
    final f = _stopInternal();
    _stopInFlight = f;
    try {
      await f;
    } finally {
      _stopInFlight = null;
    }
  }

  Future<void> _stopInternal() async {
    _isRunning = false;
    _routingActivated = false;

    // Stop Deep Simulation
    if (_deepSimulation != null) {
      _deepSimulation!.stop();
    }

    // Close all clients
    for (var client in _connectedClients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _connectedClients.clear();

    // Clear stream reassembly buffers (avoid keeping stale sockets around)
    _hsfzRxBuffers.clear();
    _doipRxBuffers.clear();

    // Close UDP sockets
    try {
      _udpSocket?.close();
      _udpSocket6811?.close();
      _udpSocket6801?.close();
    } catch (_) {}

    // Close TCP servers
    try {
      await _doipServer?.close();
      await _hsfzServer?.close();
      await _hsfzDataServer?.close();
    } catch (_) {}

    _udpSocket = null;
    _udpSocket6811 = null;
    _udpSocket6801 = null;
    _doipServer = null;
    _hsfzServer = null;
    _hsfzDataServer = null;

    _statusMessage = 'Stopped';
    _log('SYS', '🛑 Simulator stopped');
    notifyListeners();
  }

  // ============================================================
  // Network Servers
  // ============================================================

  // Additional UDP sockets for discovery
  RawDatagramSocket? _udpSocket6811;
  RawDatagramSocket? _udpSocket6801;

  // Discovery flood protection / safety
  // Default: only respond to private/link-local sources (typical workshop LAN).
  bool _allowDiscoveryFromPublicIps = false;
  Duration _discoveryRateLimit = const Duration(milliseconds: 800);
  final Map<String, DateTime> _lastDiscoveryByEndpoint = {};

  // Explicit allowlist for non-private tester IPs (e.g. VPN/virtual adapters).
  final Set<String> _discoveryIpAllowlist = <String>{};
  final Map<String, DateTime> _lastDiscoveryBlockedLogByIp = {};

  bool get allowDiscoveryFromPublicIps => _allowDiscoveryFromPublicIps;
  set allowDiscoveryFromPublicIps(bool value) {
    _allowDiscoveryFromPublicIps = value;
    notifyListeners();
  }

  Set<String> get discoveryIpAllowlist =>
      Set.unmodifiable(_discoveryIpAllowlist);

  bool addDiscoveryAllowlistIp(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;
    final parsed = InternetAddress.tryParse(trimmed);
    if (parsed == null || parsed.type != InternetAddressType.IPv4) return false;
    final added = _discoveryIpAllowlist.add(trimmed);
    if (added) notifyListeners();
    return added;
  }

  bool removeDiscoveryAllowlistIp(String ip) {
    final removed = _discoveryIpAllowlist.remove(ip.trim());
    if (removed) notifyListeners();
    return removed;
  }

  Duration get discoveryRateLimit => _discoveryRateLimit;
  set discoveryRateLimit(Duration value) {
    _discoveryRateLimit = value;
    notifyListeners();
  }

  bool _isPrivateOrLinkLocalV4(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final a = address.rawAddress;
    if (a.length != 4) return false;
    final b0 = a[0];
    final b1 = a[1];

    // Loopback
    if (b0 == 127) return true;
    // RFC1918 private ranges
    if (b0 == 10) return true;
    if (b0 == 172 && b1 >= 16 && b1 <= 31) return true;
    if (b0 == 192 && b1 == 168) return true;
    // Link-local (APIPA)
    if (b0 == 169 && b1 == 254) return true;

    // Common VPN / overlay networks that are not RFC1918 but are often used on
    // workshop laptops and virtual test rigs.
    // - Radmin VPN commonly uses 26.0.0.0/8
    // - Hamachi commonly uses 25.0.0.0/8
    if (b0 == 26) return true;
    if (b0 == 25) return true;

    // CGNAT (100.64.0.0/10) - used by some overlay VPNs (e.g., Tailscale).
    if (b0 == 100 && b1 >= 64 && b1 <= 127) return true;

    // Benchmarking / lab networks (198.18.0.0/15) sometimes used by virtualized rigs.
    if (b0 == 198 && (b1 == 18 || b1 == 19)) return true;

    return false;
  }

  bool _isDiscoverySourceAllowed(InternetAddress address) {
    if (_discoveryIpAllowlist.contains(address.address)) return true;
    if (_allowDiscoveryFromPublicIps) return true;
    return _isPrivateOrLinkLocalV4(address);
  }

  void _maybeLogDiscoveryBlocked(InternetAddress address) {
    // Avoid spamming logs in hostile networks.
    final key = address.address;
    final now = DateTime.now();
    final last = _lastDiscoveryBlockedLogByIp[key];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastDiscoveryBlockedLogByIp[key] = now;
    _log(
      'UDP',
      '⛔ Discovery blocked from $key (enable Public Discovery or add to Allowlist)',
    );
  }

  bool _shouldDropByRateLimit(String key) {
    final now = DateTime.now();
    final last = _lastDiscoveryByEndpoint[key];
    if (last != null && now.difference(last) < _discoveryRateLimit) {
      return true;
    }
    _lastDiscoveryByEndpoint[key] = now;
    if (_lastDiscoveryByEndpoint.length > 2000) {
      // Safety: avoid unbounded growth in hostile networks.
      _lastDiscoveryByEndpoint.clear();
    }
    return false;
  }

  Future<void> _startUdpServer() async {
    // Port 13400 - Standard DoIP Discovery
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort, // 13400
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null)
            _handleUdpMessage(datagram, sourceSocket: _udpSocket);
        }
      });
      _log('UDP', '✅ Listening on port $discoveryPort');
    } catch (e) {
      _log('UDP', '⚠️ Port $discoveryPort: $e');
    }

    // Port 6811 - BMW ZGW Discovery (E-Sys sends HELLO_ZGW here!)
    try {
      _udpSocket6811 = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        hsfzDataPort, // 6811
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket6811!.broadcastEnabled = true;
      _udpSocket6811!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket6811!.receive();
          if (datagram != null)
            _handleUdpMessage(datagram, sourceSocket: _udpSocket6811);
        }
      });
      _log('UDP', '✅ Listening on port $hsfzDataPort (ZGW Discovery)');
    } catch (e) {
      _log('UDP', '⚠️ Port $hsfzDataPort: $e');
    }

    // Port 6801 - BMW HSFZ Data
    try {
      _udpSocket6801 = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        hsfzPort, // 6801
        reuseAddress: true,
        reusePort: true,
      );
      _udpSocket6801!.broadcastEnabled = true;
      _udpSocket6801!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket6801!.receive();
          if (datagram != null)
            _handleUdpMessage(datagram, sourceSocket: _udpSocket6801);
        }
      });
      _log('UDP', '✅ Listening on port $hsfzPort');
    } catch (e) {
      _log('UDP', '⚠️ Port $hsfzPort: $e');
    }
  }

  void _handleUdpMessage(Datagram datagram, {RawDatagramSocket? sourceSocket}) {
    final data = datagram.data;

    // Ignore our own broadcast responses (contains DIAGADR = our response)
    if (data.length > 10) {
      final dataStr = String.fromCharCodes(data.take(50));
      if (dataStr.contains('DIAGADR')) {
        // This is our own response echoed back, ignore it
        return;
      }
    }

    // Ignore DoIP Vehicle Announcements (0x0004) - these are our broadcasts
    if (data.length >= 8 &&
        data[0] == doipVersion &&
        data[1] == doipInverseVersion) {
      final payloadType = (data[2] << 8) | data[3];
      if (payloadType == 0x0004) {
        // This is our own Vehicle Announcement, ignore
        return;
      }
    }

    // Use the socket that received the message to send response
    final replySocket = sourceSocket ?? _udpSocket;

    // BMW ZGW Discovery (HSFZ) - Check for 00 00 00 00 00 11 pattern (HELLO_ZGW)
    if (data.length == 6 && data[5] == 0x11) {
      if (!_isDiscoverySourceAllowed(datagram.address)) {
        // Do not respond to public sources by default.
        _maybeLogDiscoveryBlocked(datagram.address);
        return;
      }

      final key = 'HELLO_ZGW@${datagram.address.address}:${datagram.port}';
      if (_shouldDropByRateLimit(key)) {
        return;
      }

      _log(
        'UDP',
        '📥 From ${datagram.address.address}:${datagram.port} - ${_bytesToHex(data)}',
      );
      _log(
        'UDP',
        '🔍 ZGW Discovery (HELLO_ZGW) from ${datagram.address.address}:${datagram.port}',
      );
      final response = _buildZGWResponse();
      // Send response back to requester using the SAME socket
      replySocket?.send(response, datagram.address, datagram.port);
      _log(
        'UDP',
        '📤 Sent ZGW Response to ${datagram.address.address}:${datagram.port}',
      );
      return;
    }

    // HSFZ Discovery with length prefix - but NOT responses (which have payload)
    if (data.length >= 6 && data.length <= 10) {
      final packetType = (data[4] << 8) | data[5];
      if (packetType == 0x0011) {
        if (!_isDiscoverySourceAllowed(datagram.address)) {
          _maybeLogDiscoveryBlocked(datagram.address);
          return;
        }

        final key = 'HSFZ_DISC@${datagram.address.address}:${datagram.port}';
        if (_shouldDropByRateLimit(key)) {
          return;
        }

        _log(
          'UDP',
          '📥 From ${datagram.address.address}:${datagram.port} - ${_bytesToHex(data)}',
        );
        _log(
          'UDP',
          '🔍 HSFZ Discovery from ${datagram.address.address}:${datagram.port}',
        );
        final response = _buildZGWResponse();
        replySocket?.send(response, datagram.address, datagram.port);
        _log('UDP', '📤 Sent HSFZ Response');
        return;
      }
    }

    // DoIP Vehicle Identification Request
    if (data.length >= 8 &&
        data[0] == doipVersion &&
        data[1] == doipInverseVersion) {
      final payloadType = (data[2] << 8) | data[3];

      if (payloadType == 0x0001 ||
          payloadType == 0x0002 ||
          payloadType == 0x0003) {
        if (!_isDiscoverySourceAllowed(datagram.address)) {
          _maybeLogDiscoveryBlocked(datagram.address);
          return;
        }

        final key =
            'DOIP_VID@${datagram.address.address}:${datagram.port}:$payloadType';
        if (_shouldDropByRateLimit(key)) {
          return;
        }

        _log(
          'UDP',
          '📥 From ${datagram.address.address}:${datagram.port} - ${_bytesToHex(data)}',
        );
        _log(
          'UDP',
          '🔍 DoIP Vehicle ID request from ${datagram.address.address}',
        );
        final announcement = _buildDoIPVehicleAnnouncement();
        replySocket?.send(announcement, datagram.address, datagram.port);
        _log('UDP', '📤 Sent Vehicle Announcement');
        return;
      }

      // Entity Status Request (0x4001)
      if (payloadType == 0x4001) {
        if (!_isDiscoverySourceAllowed(datagram.address)) {
          _maybeLogDiscoveryBlocked(datagram.address);
          return;
        }
        final response = _buildEntityStatusResponse();
        replySocket?.send(response, datagram.address, datagram.port);
        return;
      }

      // Power Mode Request (0x4003)
      if (payloadType == 0x4003) {
        if (!_isDiscoverySourceAllowed(datagram.address)) {
          _maybeLogDiscoveryBlocked(datagram.address);
          return;
        }
        final response = _buildPowerModeResponse();
        replySocket?.send(response, datagram.address, datagram.port);
        return;
      }
    }

    // Log everything else (non-discovery) as before.
    _log(
      'UDP',
      '📥 From ${datagram.address.address}:${datagram.port} - ${_bytesToHex(data)}',
    );
  }

  /// Build Entity Status Response (0x4002)
  Uint8List _buildEntityStatusResponse() {
    // NodeType(1) + MaxSockets(1) + OpenSockets(1) + MaxDataSize(4)
    final payload = Uint8List(7);
    payload[0] = 0x00; // Node type: DoIP Gateway
    payload[1] = 0x10; // Max concurrent TCP sockets
    payload[2] = _connectedClients.length & 0xFF; // Currently open sockets
    // Max data size (4 bytes) = 4096
    payload[3] = 0x00;
    payload[4] = 0x00;
    payload[5] = 0x10;
    payload[6] = 0x00;
    return _buildDoIPMessage(0x4002, payload);
  }

  /// Build Power Mode Response (0x4004)
  Uint8List _buildPowerModeResponse() {
    // PowerMode: 0x01 = Ready
    return _buildDoIPMessage(0x4004, Uint8List.fromList([0x01]));
  }

  Uint8List _buildZGWResponse() {
    // HSFZ format for E-Sys discovery:
    // Header: 4 bytes length + 2 bytes type (0x0011)
    // Payload: DIAGADR<XX>BMWMAC<MAC12>BMWVIN<VIN17>

    final vehicleVin = _streamingVehicle?.vin ?? vin;
    final diagAddr = '10'; // ZGW address as 2 hex chars
    final macHex = '001A37010203'; // MAC as 12 hex chars
    final vinClean = vehicleVin.padRight(17, '0').substring(0, 17);

    // Build payload string - E-Sys format
    final payloadStr = 'DIAGADR${diagAddr}BMWMAC${macHex}BMWVIN$vinClean';
    final payloadBytes = payloadStr.codeUnits;

    // Build HSFZ header: 4 bytes length + 2 bytes type (0x0011)
    final response = Uint8List(6 + payloadBytes.length);
    // Length (4 bytes big-endian)
    response[0] = (payloadBytes.length >> 24) & 0xFF;
    response[1] = (payloadBytes.length >> 16) & 0xFF;
    response[2] = (payloadBytes.length >> 8) & 0xFF;
    response[3] = payloadBytes.length & 0xFF;
    // Type (2 bytes) = 0x0011
    response[4] = 0x00;
    response[5] = 0x11;
    // Payload
    response.setRange(6, 6 + payloadBytes.length, payloadBytes);

    return response;
  }

  /// Build DoIP Vehicle Announcement (0x0004)
  Uint8List _buildDoIPVehicleAnnouncement() {
    final vehicleVin = _streamingVehicle?.vin ?? vin;

    // Payload: VIN(17) + LogicalAddr(2) + EID(6) + GID(6) + FurtherAction(1) + SyncStatus(1)
    final payload = Uint8List(33);

    // VIN - 17 bytes
    final vinBytes =
        vehicleVin.padRight(17, '\x00').codeUnits.take(17).toList();
    payload.setRange(0, 17, vinBytes);

    // Logical Address - 2 bytes
    payload[17] = (_logicalAddress >> 8) & 0xFF;
    payload[18] = _logicalAddress & 0xFF;

    // EID (Entity ID / MAC) - 6 bytes
    payload.setRange(19, 25, [0x00, 0x1A, 0x37, 0x01, 0x02, 0x03]);

    // GID (Group ID) - 6 bytes
    payload.setRange(25, 31, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

    // Further Action Required - 1 byte (0x00 = no further action)
    payload[31] = 0x00;

    // VIN/GID Sync Status - 1 byte (0x00 = synchronized)
    payload[32] = 0x00;

    return _buildDoIPMessage(0x0004, payload);
  }

  Future<void> _startDoIPServer() async {
    try {
      _doipServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        doipPort,
        shared: true,
      );
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048) {
        // Windows: WSAEADDRINUSE
        _log(
          'ERR',
          'DoIP TCP bind failed on port $doipPort (already in use). Close other bmw_psdz_ultimate.exe instances or any DoIP tool, then retry.',
        );
      }
      rethrow;
    }

    _doipServer!.listen((client) {
      _log('TCP', '🔌 DoIP client: ${client.remoteAddress.address}');
      _connectedClients.add(client);
      notifyListeners();

      _doipRxBuffers[client] = <int>[];

      client.listen(
        (data) => _handleDoIPStreamData(client, Uint8List.fromList(data)),
        onDone: () {
          _doipRxBuffers.remove(client);
          _connectedClients.remove(client);
          _log('TCP', '🔌 DoIP disconnected');
          notifyListeners();
        },
        onError: (e) {
          _doipRxBuffers.remove(client);
          _connectedClients.remove(client);
        },
      );
    });
  }

  void _handleDoIPStreamData(Socket client, Uint8List data) {
    final buf = _doipRxBuffers.putIfAbsent(client, () => <int>[]);
    buf.addAll(data);

    // DoIP header is 8 bytes: ver, inv, type(2), len(4)
    while (buf.length >= 8) {
      // Validate header bytes early
      if (buf[0] != doipVersion || buf[1] != doipInverseVersion) {
        // Desync - drop one byte to resync
        buf.removeAt(0);
        continue;
      }

      final payloadLen =
          (buf[4] << 24) | (buf[5] << 16) | (buf[6] << 8) | (buf[7]);
      if (payloadLen < 0 || payloadLen > _maxDoipPayloadLen) {
        _log('TCP', '⚠️ DoIP invalid length: $payloadLen (dropping buffer)');
        buf.clear();
        return;
      }

      final totalLen = 8 + payloadLen;
      if (buf.length < totalLen) return; // wait for more bytes

      final frame = Uint8List.fromList(buf.sublist(0, totalLen));
      buf.removeRange(0, totalLen);
      _handleDoIPFrame(client, frame);
    }
  }

  void _handleDoIPFrame(Socket client, Uint8List data) {
    if (data.length < 8) return;
    if (data[0] != doipVersion || data[1] != doipInverseVersion) return;

    final payloadType = (data[2] << 8) | data[3];
    final payloadLen =
        (data[4] << 24) | (data[5] << 16) | (data[6] << 8) | (data[7]);
    if (payloadLen < 0 || payloadLen > _maxDoipPayloadLen) return;

    final payload =
        payloadLen > 0 ? data.sublist(8, 8 + payloadLen) : Uint8List(0);

    switch (payloadType) {
      case 0x0001: // Vehicle ID Request
        client.add(_buildDoIPVehicleAnnouncement());
        break;
      case 0x0005: // Routing Activation
        _handleRoutingActivation(client, payload);
        break;
      case 0x0007: // Alive Check
        final resp = _buildDoIPMessage(
          0x0008,
          Uint8List.fromList([
            (_logicalAddress >> 8) & 0xFF,
            _logicalAddress & 0xFF,
          ]),
        );
        client.add(resp);
        break;
      case 0x8001: // Diagnostic Message
        _handleDiagnosticMessage(client, payload);
        break;
    }
  }

  void _handleRoutingActivation(Socket client, Uint8List payload) {
    if (payload.length < 7) return;

    _testerAddress = (payload[0] << 8) | payload[1];
    _routingActivated = true;

    _log(
      'ROUTE',
      '🔑 Tester 0x${_testerAddress.toRadixString(16).toUpperCase()}',
    );

    // ISO 13400-2: Routing Activation Response payload is 13 bytes:
    // SA(2) + LA(2) + ResponseCode(1) + Reserved(4) + OEMSpecific(4)
    final respPayload = Uint8List(13);
    respPayload[0] = (_testerAddress >> 8) & 0xFF;
    respPayload[1] = _testerAddress & 0xFF;
    respPayload[2] = (_logicalAddress >> 8) & 0xFF;
    respPayload[3] = _logicalAddress & 0xFF;
    respPayload[4] = 0x10; // Success (OEM specific usage in many BMW stacks)
    // respPayload[5..8] reserved = 0
    // respPayload[9..12] OEM specific = 0

    client.add(_buildDoIPMessage(0x0006, respPayload));
    notifyListeners();
  }

  Future<void> _handleDiagnosticMessage(
    Socket client,
    Uint8List payload,
  ) async {
    if (payload.length < 4) return;

    final sourceAddr = (payload[0] << 8) | payload[1];
    final targetAddr = (payload[2] << 8) | payload[3];
    final udsData = payload.sublist(4);

    _totalRequests++;
    _ecuRequestCounts[targetAddr] = (_ecuRequestCounts[targetAddr] ?? 0) + 1;

    _log(
      'UDS',
      '📨 [0x${targetAddr.toRadixString(16)}] ${_bytesToHex(udsData)}',
    );

    // Send ACK immediately (ISO 13400 requirement)
    final ackPayload = Uint8List(5);
    ackPayload[0] = (targetAddr >> 8) & 0xFF;
    ackPayload[1] = targetAddr & 0xFF;
    ackPayload[2] = (sourceAddr >> 8) & 0xFF;
    ackPayload[3] = sourceAddr & 0xFF;
    ackPayload[4] = 0x00;
    client.add(_buildDoIPMessage(0x8002, ackPayload));

    // Simulate ECU processing time
    // Real ECUs are not instant. This helps avoid flooding the client.
    if (udsData.isNotEmpty) {
      final sid = udsData[0];
      int delayMs = 2; // Base latency

      // Add specific delays for heavy operations
      if (sid == 0x11) delayMs = 50; // ECU Reset
      if (sid == 0x14) delayMs = 150; // Clear DTCs
      if (sid == 0x31) delayMs = 20; // Routine Control
      if (sid == 0x27) delayMs = 10; // Security Access
      if (sid == 0x2E) delayMs = 15; // Write Data

      if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));
    }

    // Process UDS
    final response = _processUDS(targetAddr, udsData);
    if (response != null && response.isNotEmpty) {
      _totalResponses++;

      final diagPayload = Uint8List(4 + response.length);
      diagPayload[0] = (targetAddr >> 8) & 0xFF;
      diagPayload[1] = targetAddr & 0xFF;
      diagPayload[2] = (sourceAddr >> 8) & 0xFF;
      diagPayload[3] = sourceAddr & 0xFF;
      diagPayload.setRange(4, diagPayload.length, response);

      client.add(_buildDoIPMessage(0x8001, diagPayload));
      _log(
        'UDS',
        '📩 [0x${targetAddr.toRadixString(16)}] ${_bytesToHex(response)}',
      );
    }
  }

  Future<void> _startHSFZServers() async {
    // Control port
    _hsfzServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      hsfzPort,
      shared: true,
    );
    _hsfzServer!.listen((client) {
      _log(
        'HSFZ',
        '🔌 Client: ${client.remoteAddress.address}:${client.remotePort} → $hsfzPort',
      );
      _connectedClients.add(client);
      notifyListeners();

      _hsfzRxBuffers[client] = <int>[];

      // Send session ready notification to client
      _sendSessionReady(client);

      client.listen(
        (data) => _handleHSFZStreamData(client, Uint8List.fromList(data)),
        onDone: () {
          _log('HSFZ', '🔌 Client disconnected');
          _hsfzRxBuffers.remove(client);
          _connectedClients.remove(client);
          notifyListeners();
        },
        onError: (e) {
          _log('HSFZ', '❌ Client error: $e');
          _hsfzRxBuffers.remove(client);
          _connectedClients.remove(client);
        },
      );
    });

    // Data port
    _hsfzDataServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      hsfzDataPort,
      shared: true,
    );
    _hsfzDataServer!.listen((client) {
      _log(
        'HSFZ',
        '🔌 Data: ${client.remoteAddress.address}:${client.remotePort} → $hsfzDataPort',
      );
      _connectedClients.add(client);
      notifyListeners();

      _hsfzRxBuffers[client] = <int>[];

      // Some clients (incl. ISTA in certain setups) open a second socket and
      // still expect the "session ready" indication on it.
      _sendSessionReady(client);

      client.listen(
        (data) => _handleHSFZStreamData(client, Uint8List.fromList(data)),
        onDone: () {
          _log('HSFZ', '🔌 Data client disconnected');
          _hsfzRxBuffers.remove(client);
          _connectedClients.remove(client);
          notifyListeners();
        },
        onError: (e) {
          _log('HSFZ', '❌ Data client error: $e');
          _hsfzRxBuffers.remove(client);
          _connectedClients.remove(client);
        },
      );
    });
  }

  void _handleHSFZStreamData(Socket client, Uint8List data) {
    final buf = _hsfzRxBuffers.putIfAbsent(client, () => <int>[]);
    buf.addAll(data);

    // HSFZ header is 6 bytes: len(4) + type(2)
    while (buf.length >= 6) {
      final payloadLen =
          (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | (buf[3]);
      if (payloadLen < 0 || payloadLen > _maxHsfzPayloadLen) {
        _log('HSFZ', '⚠️ HSFZ invalid length: $payloadLen (dropping buffer)');
        buf.clear();
        return;
      }

      final totalLen = 6 + payloadLen;
      if (buf.length < totalLen) return; // wait

      final frame = Uint8List.fromList(buf.sublist(0, totalLen));
      buf.removeRange(0, totalLen);
      _handleHSFZFrame(client, frame);
    }
  }

  void _handleHSFZFrame(Socket client, Uint8List data) {
    if (data.length < 6) return;

    // HSFZ Header: 4 bytes length + 2 bytes packet_type
    final payloadLen =
        (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
    final packetType = (data[4] << 8) | data[5];
    if (payloadLen < 0 || payloadLen > _maxHsfzPayloadLen) return;
    final payload =
        payloadLen > 0 ? data.sublist(6, 6 + payloadLen) : Uint8List(0);

    // Only log diagnostic messages and non-repetitive control messages
    // Reduce log spam from alive checks (0x0012) and status inquiries (0x0013)
    if (packetType == 0x0001) {
      _log(
        'HSFZ',
        '📨 Type=0x${packetType.toRadixString(16).padLeft(4, '0')} Len=$payloadLen',
      );
    }

    switch (packetType) {
      case 0x0001: // Diagnostic message
        if (payload.length >= 2) {
          // HSFZ format: [SRC=Tester][DST=ECU][UDS...]
          final sourceAddr = payload[0]; // Tester address (e.g., 0xF4)
          final targetAddr = payload[1]; // ECU address (e.g., 0x10)
          final udsData =
              payload.length > 2 ? payload.sublist(2) : Uint8List(0);

          _totalRequests++;
          _log(
            'HSFZ',
            '📨 0x${sourceAddr.toRadixString(16)}→0x${targetAddr.toRadixString(16)} UDS: ${_bytesToHex(udsData)}',
          );

          final response = _processUDS(targetAddr, udsData);
          if (response != null && response.isNotEmpty) {
            _totalResponses++;
            // Response format: [SRC=ECU][DST=Tester][UDS...]
            final respPayload = Uint8List(2 + response.length);
            respPayload[0] = targetAddr; // ECU as source
            respPayload[1] = sourceAddr; // Tester as destination
            respPayload.setRange(2, respPayload.length, response);

            client.add(_buildHSFZResponse(0x0001, respPayload));
            _log(
              'HSFZ',
              '📩 0x${targetAddr.toRadixString(16)}→0x${sourceAddr.toRadixString(16)} ${_bytesToHex(response)}',
            );
          } else {
            // Send negative response - service not supported
            final sid = udsData.isNotEmpty ? udsData[0] : 0x00;
            final nrc = Uint8List.fromList([
              0x7F,
              sid,
              0x11,
            ]); // 0x11 = serviceNotSupported
            final respPayload = Uint8List(2 + nrc.length);
            respPayload[0] = targetAddr;
            respPayload[1] = sourceAddr;
            respPayload.setRange(2, respPayload.length, nrc);
            client.add(_buildHSFZResponse(0x0001, respPayload));
            _log('HSFZ', '📩 NRC: ${_bytesToHex(nrc)}');
          }
        }
        break;

      case 0x0002: // Echo request
        client.add(_buildHSFZResponse(0x0002, payload));
        break;

      case 0x0010: // Alive Check Request
        client.add(_buildHSFZResponse(0x0010, Uint8List(0)));
        break;

      case 0x0011: // Vehicle Ident Data (shouldn't happen on TCP often)
        client.add(_buildZGWResponse());
        break;

      case 0x0012: // Alive Check / Session Establishment
        // Per Scapy HSFZ spec: control=0x12 is alive_check
        // When length=2, payload contains source/target addresses
        // Respond with same payload to confirm session
        client.add(
          _buildHSFZResponse(
            0x0012,
            payload.isNotEmpty ? payload : Uint8List.fromList([0x00, 0x00]),
          ),
        );
        if (!_routingActivated) {
          _routingActivated = true;
          _log('HSFZ', '✅ Session established');
          notifyListeners();
        }
        // Don't log repeated alive checks to reduce log spam
        break;

      case 0x0013: // Status Data Inquiry
        // ISTA sends this for status checks. Echo back payload.
        client.add(
          _buildHSFZResponse(
            0x0013,
            payload.isNotEmpty ? payload : Uint8List.fromList([0x00, 0x00]),
          ),
        );
        // Don't log repeated status inquiries to reduce spam
        break;

      case 0x0014: // Session Close Request
        // Close session gracefully - echo payload when present.
        client.add(
          _buildHSFZResponse(
            0x0014,
            payload.isNotEmpty ? payload : Uint8List.fromList([0x00, 0x00]),
          ),
        );
        _log('HSFZ', '📤 Session Close ACK');
        break;

      case 0x0040: // BMW Session Handshake
        // Accept session - echo back
        client.add(_buildHSFZResponse(0x0040, payload));
        _log('HSFZ', '✅ Handshake accepted');
        break;

      case 0x3E00: // Keep Alive (TesterPresent)
        client.add(_buildHSFZResponse(0x3E00, Uint8List.fromList([0x00])));
        break;

      default:
        _log(
          'HSFZ',
          '⚠️ Unknown packet type: 0x${packetType.toRadixString(16)}',
        );
    }
  }

  /// Send session ready notification to client on connect
  void _sendSessionReady(Socket client) {
    try {
      // HSFZ Session Ready. ISTA commonly uses 2-byte payloads for session packets.
      final sessionReady = _buildHSFZResponse(
        0x0012,
        Uint8List.fromList([0x00, 0x00]),
      );
      client.add(sessionReady);
      _routingActivated = true;
      _log('HSFZ', '📤 Session Ready sent to client');
    } catch (e) {
      _log('HSFZ', '❌ Failed to send session ready: $e');
    }
  }

  Uint8List _buildHSFZResponse(int packetType, Uint8List payload) {
    // HSFZ Header: 4 bytes length + 2 bytes packet_type + payload
    final message = Uint8List(6 + payload.length);
    // Length (4 bytes big-endian) = payload length only
    message[0] = (payload.length >> 24) & 0xFF;
    message[1] = (payload.length >> 16) & 0xFF;
    message[2] = (payload.length >> 8) & 0xFF;
    message[3] = payload.length & 0xFF;
    // Packet type (2 bytes big-endian)
    message[4] = (packetType >> 8) & 0xFF;
    message[5] = packetType & 0xFF;
    // Payload
    if (payload.isNotEmpty) {
      message.setRange(6, message.length, payload);
    }
    return message;
  }

  Uint8List _buildDoIPMessage(int payloadType, Uint8List payload) {
    final message = Uint8List(8 + payload.length);
    message[0] = doipVersion;
    message[1] = doipInverseVersion;
    message[2] = (payloadType >> 8) & 0xFF;
    message[3] = payloadType & 0xFF;
    message[4] = (payload.length >> 24) & 0xFF;
    message[5] = (payload.length >> 16) & 0xFF;
    message[6] = (payload.length >> 8) & 0xFF;
    message[7] = payload.length & 0xFF;
    message.setRange(8, message.length, payload);
    return message;
  }

  // ============================================================
  // UDS Processing
  // ============================================================

  Uint8List? _processUDS(int targetAddr, Uint8List request) {
    if (request.isEmpty) {
      _totalErrors++;
      return Uint8List.fromList([0x7F, 0x00, 0x10]);
    }

    // Deep Simulation Hook - Real-time response generation from PSDZ/NCD
    if (_useDeepSimulation &&
        _deepSimulation != null &&
        _deepSimulation!.isInitialized) {
      final response = _deepSimulation!.processRequest(targetAddr, request);
      if (response != null) {
        _log(
          'DEEP',
          '⚡ Generated dynamic response for 0x${targetAddr.toRadixString(16)}',
        );
        return response;
      }
    }

    // Find target ECU
    VirtualECU? ecu = _ecus[targetAddr];

    // Special handling for known addresses
    if (ecu == null) {
      // Functional addresses and ZGW
      if (targetAddr == 0xDF || targetAddr == 0x1010 || targetAddr == 0x10) {
        ecu = _zgwEcu;
        _log(
          'UDS',
          '🎯 Routing to ZGW (target=0x${targetAddr.toRadixString(16)})',
        );
      } else {
        // Create ECU on-the-fly
        ecu = VirtualECU(
          diagAddress: targetAddr,
          name: 'ECU_${targetAddr.toRadixString(16)}',
        );

        // Copy data from ZGW
        if (_zgwEcu?.faData != null) ecu.loadFA(_zgwEcu!.faData!);
        if (_zgwEcu?.svtData != null) ecu.loadSVT(_zgwEcu!.svtData!);
        if (_streamingVehicle != null) ecu.vin = _streamingVehicle!.vin;
        if (_zgwEcu != null) {
          ecu.iStep = _zgwEcu!.iStep;
          // Copy essential VCM DIDs
          for (final did in [
            0xF190,
            0x1769,
            0x3FD0,
            0x2503,
            0x2504,
            0x2505,
            0x3F06,
            0x3F07,
            0x3F08,
            0x100B,
            0x100C,
            0x100D,
          ]) {
            final data = _zgwEcu!.getDID(did);
            if (data != null) ecu.setDID(did, data);
          }
        }

        _ecus[targetAddr] = ecu;
        _log(
          'UDS',
          '🔧 Created ECU 0x${targetAddr.toRadixString(16)} on-the-fly',
        );
      }
    }

    // Log VCM-related requests
    if (request.isNotEmpty) {
      final sid = request[0];
      if (sid == 0x22 && request.length >= 3) {
        final did = (request[1] << 8) | request[2];
        if ([
          0x1769,
          0x2503,
          0x2504,
          0x2505,
          0x3F06,
          0x3F07,
          0x3F08,
          0x100B,
          0x100C,
          0x100D,
          0xF150,
          0xF1D0,
          0xF1D1,
          0xF1D2,
        ].contains(did)) {
          _log(
            'VCM',
            '📖 ReadDID 0x${did.toRadixString(16).padLeft(4, '0')} (${_getVCMDIDName(did)})',
          );
        }
      } else if (sid == 0x31 && request.length >= 4) {
        final routineId = (request[2] << 8) | request[3];
        if (routineId >= 0x0200 && routineId <= 0x020A) {
          _log(
            'VCM',
            '🔧 Routine 0x${routineId.toRadixString(16).padLeft(4, '0')} (${_getVCMRoutineName(routineId)})',
          );
        }
      }
    }

    return ecu?.processRequest(request);
  }

  String _getVCMDIDName(int did) {
    switch (did) {
      case 0x1769:
        return 'VCM FA';
      case 0x2503:
        return 'I-Step Shipment';
      case 0x2504:
        return 'I-Step Current';
      case 0x2505:
        return 'I-Step Last';
      case 0x3F06:
        return 'I-Step E-Sys';
      case 0x3F07:
        return 'I-Step Current (ISTA)';
      case 0x3F08:
        return 'I-Step Last (ISTA)';
      case 0x100B:
        return 'I-Step Current (E-Sys)';
      case 0x100C:
        return 'I-Step Last (E-Sys)';
      case 0x100D:
        return 'I-Step Factory (E-Sys)';
      case 0xF150:
        return 'SVK';
      case 0xF1D0:
        return 'VCM Status';
      case 0xF1D1:
        return 'VCM Backup Status';
      case 0xF1D2:
        return 'VCM Master Status';
      default:
        return 'Unknown';
    }
  }

  String _getVCMRoutineName(int routineId) {
    switch (routineId) {
      case 0x0200:
        return 'VCM Status Check';
      case 0x0201:
        return 'VCM Check Backup';
      case 0x0202:
        return 'VCM Check Master';
      case 0x0203:
        return 'Read FA';
      case 0x0204:
        return 'Write FA';
      case 0x0205:
        return 'Read FP';
      case 0x0206:
        return 'Read SVK';
      case 0x0207:
        return 'Read I-Step Shipment';
      case 0x0208:
        return 'Read I-Step Current';
      case 0x0209:
        return 'Read I-Step Last';
      case 0x020A:
        return 'Read VCM Dataset';
      default:
        return 'Unknown';
    }
  }

  // ============================================================
  // Announcements
  // ============================================================

  void _sendAnnouncements() {
    if (!_isRunning) return;

    try {
      // Build responses
      final doipAnnouncement = _buildDoIPVehicleAnnouncement();
      final zgwResponse = _buildZGWResponse();

      // Get local IP for subnet broadcast
      _getLocalSubnetBroadcast().then((subnetBroadcast) {
        final broadcastTargets = [
          InternetAddress('255.255.255.255'),
          if (subnetBroadcast != null) subnetBroadcast,
        ];

        // Send DoIP Announcement on port 13400 (standard DoIP)
        if (_udpSocket != null) {
          for (final target in broadcastTargets) {
            try {
              _udpSocket!.send(doipAnnouncement, target, doipPort);
            } catch (_) {}
          }
        }

        // Send ZGW Response on port 6811 (BMW ZGW Discovery) - THIS IS WHAT E-SYS LISTENS ON
        if (_udpSocket6811 != null) {
          for (final target in broadcastTargets) {
            try {
              _udpSocket6811!.send(zgwResponse, target, hsfzDataPort); // 6811
            } catch (_) {}
          }
        }

        _log('BCAST', '📡 Broadcast: DoIP→13400, ZGW→6811');
      });
    } catch (e) {
      debugPrint('Announcement error: $e');
    }

    // Repeat every 2 seconds while running
    if (_isRunning) {
      Future.delayed(const Duration(seconds: 2), _sendAnnouncements);
    }
  }

  Future<InternetAddress?> _getLocalSubnetBroadcast() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              addr.address.startsWith('192.168.')) {
            final parts = addr.address.split('.');
            return InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  String _bytesToHex(List<int> bytes) {
    return bytes
            .take(32)
            .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
            .join(' ') +
        (bytes.length > 32 ? '...' : '');
  }

  void _log(String type, String message) {
    final timestamp = DateTime.now();
    _logs.add(LogEntry(timestamp: timestamp, type: type, message: message));
    if (_logs.length > 1000) _logs.removeAt(0);
    debugPrint('[$type] $message');
    notifyListeners();
  }

  /// Public log method
  void addLog(String type, String message) {
    _log(type, message);
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Get ECU by address
  VirtualECU? getECU(int address) => _ecus[address];

  /// Get ECU request statistics
  Map<int, int> get ecuRequestStats => Map.unmodifiable(_ecuRequestCounts);

  /// Set VIN manually
  void setVIN(String vin) {
    _setVinForAllEcus(vin);
    _log('VIN', 'Set VIN: $vin');
    notifyListeners();
  }

  /// Set I-Step manually
  void setIStep(String istep) {
    _setIStepForAllEcus(istep);
    _log('ISTEP', 'Set I-Step: $istep');
    notifyListeners();
  }

  /// NBT EVO controls
  void enableVideoInMotion(bool enabled) {
    _nbtEvoEcu?.setVideoInMotion(enabled);
    _log('NBT', 'Video in Motion: ${enabled ? 'ON' : 'OFF'}');
    notifyListeners();
  }

  void enableDeveloperMenu(bool enabled) {
    _nbtEvoEcu?.setDeveloperMenu(enabled);
    _log('NBT', 'Developer Menu: ${enabled ? 'ON' : 'OFF'}');
    notifyListeners();
  }

  /// Add DTC to ECU
  void addDTC(int ecuAddress, int dtcCode) {
    final ecu = _ecus[ecuAddress];
    if (ecu != null) {
      ecu.addDTC(dtcCode);
      _log(
        'DTC',
        'Added 0x${dtcCode.toRadixString(16)} to ECU 0x${ecuAddress.toRadixString(16)}',
      );
      notifyListeners();
    }
  }

  /// Clear DTCs for ECU
  void clearDTCs(int ecuAddress) {
    final ecu = _ecus[ecuAddress];
    if (ecu != null) {
      ecu.clearDTCs();
      _log('DTC', 'Cleared DTCs for ECU 0x${ecuAddress.toRadixString(16)}');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Log entry
class LogEntry {
  final DateTime timestamp;
  final String type;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
  });

  String get timeString => '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';

  @override
  String toString() => '[$timeString] [$type] $message';
}
