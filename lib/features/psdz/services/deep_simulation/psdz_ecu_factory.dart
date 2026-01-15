/// PSDZ ECU Factory - Create virtual ECUs from PSDZ/SVT data
/// Builds complete ECU instances with authentic responses
///
/// Features:
/// - Auto-detect ECU type from SVT
/// - Load appropriate CAFD/NCD files
/// - Configure DIDs from mapping files
/// - Build SVK from software parts
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library psdz_ecu_factory;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../virtual_ecu.dart';
import '../nbt_evo_ecu.dart';
import 'psdz_mapping_service.dart';
import 'ncd_cafd_loader.dart';
import 'deep_ecu_mapping_engine.dart';
import 'dynamic_response_engine.dart';

/// ECU Creation Strategy
enum EcuCreationStrategy {
  /// Basic ECU with minimal responses
  minimal,

  /// Standard ECU with common DIDs
  standard,

  /// Full ECU with all available data
  full,

  /// Deep simulation with NCD/CAFD data
  deep,
}

/// PSDZ ECU Factory
class PsdzEcuFactory extends ChangeNotifier {
  // Services
  final PsdzMappingService _mappingService;
  final NcdCafdLoader _ncdCafdLoader;
  final DynamicResponseEngine _responseEngine;

  // Created ECUs
  final Map<int, VirtualECU> _createdEcus = {};

  // State
  bool _isInitialized = false;
  String _statusMessage = 'Not initialized';

  // Vehicle context
  String _vin = 'WBA00000000000000';
  String _iStep = 'G030-24-03-550';
  FAData? _faData;
  SVTData? _svtData;

  // Getters
  bool get isInitialized => _isInitialized;
  String get statusMessage => _statusMessage;
  List<VirtualECU> get createdEcus => _createdEcus.values.toList();
  int get ecuCount => _createdEcus.length;

  PsdzEcuFactory({
    required PsdzMappingService mappingService,
    required NcdCafdLoader ncdCafdLoader,
    required DynamicResponseEngine responseEngine,
  }) : _mappingService = mappingService,
       _ncdCafdLoader = ncdCafdLoader,
       _responseEngine = responseEngine;

  /// Initialize factory with PSDZ data
  Future<void> initialize() async {
    _statusMessage = 'Initializing PSDZ ECU Factory...';
    notifyListeners();

    try {
      // Index PSDZ mappings if not already done
      if (!_mappingService.isLoaded) {
        await _mappingService.indexMappings();
      }

      _isInitialized = true;
      _statusMessage =
          'Factory ready - ${_mappingService.totalMappings} mappings loaded';
      debugPrint('PsdzEcuFactory: $_statusMessage');
    } catch (e) {
      _statusMessage = 'Initialization error: $e';
      debugPrint('PsdzEcuFactory Error: $e');
    }

    notifyListeners();
  }

  /// Set vehicle context for ECU creation
  void setVehicleContext({
    required String vin,
    required String iStep,
    FAData? faData,
    SVTData? svtData,
  }) {
    _vin = vin;
    _iStep = iStep;
    _faData = faData;
    _svtData = svtData;

    // Update response engine
    _responseEngine.loadVehicleData(
      vin: vin,
      iStep: iStep,
      faData: faData,
      svtData: svtData,
    );

    // Update all existing ECUs
    for (final ecu in _createdEcus.values) {
      ecu.vin = vin;
      ecu.iStep = iStep;
      if (faData != null) ecu.loadFA(faData);
      if (svtData != null) ecu.loadSVT(svtData);
    }

    notifyListeners();
  }

  /// Create ECU from SVT entry
  Future<VirtualECU?> createFromSvtEntry(
    SVTEcuData svtEntry, {
    EcuCreationStrategy strategy = EcuCreationStrategy.deep,
  }) async {
    try {
      final address = svtEntry.address;
      final name = svtEntry.name;

      debugPrint('Creating ECU: $name [0x${address.toRadixString(16)}]');

      // Check for specialized ECU types
      VirtualECU ecu;

      if (_isNbtEvo(name)) {
        ecu = NbtEvoEcu(
          diagAddress: address,
          name: name,
          psdzDataPath: _mappingService.psdzBasePath,
        );
      } else {
        ecu = VirtualECU(diagAddress: address, name: name);
      }

      // Set base vehicle data
      ecu.vin = _vin;
      ecu.iStep = _iStep;

      // Load FA/SVT
      if (_faData != null) ecu.loadFA(_faData!);
      if (_svtData != null) ecu.loadSVT(_svtData!);

      // Load SVT parts into ECU (already ECUPart from SVTEcuData)
      for (final part in svtEntry.parts) {
        ecu.addPart(part);
      }

      // Deep loading if requested
      if (strategy == EcuCreationStrategy.deep ||
          strategy == EcuCreationStrategy.full) {
        await _loadDeepData(ecu, svtEntry);
      }

      _createdEcus[address] = ecu;
      notifyListeners();

      return ecu;
    } catch (e) {
      debugPrint('Error creating ECU ${svtEntry.name}: $e');
      return null;
    }
  }

  /// Create ECU by address
  Future<VirtualECU?> createByAddress(
    int address, {
    String? name,
    EcuCreationStrategy strategy = EcuCreationStrategy.standard,
  }) async {
    // Get ECU info from registry
    final info = BmwEcuAddressRegistry.getByAddress(address);
    final ecuName =
        name ?? info?.shortName ?? 'ECU_${address.toRadixString(16)}';

    // Check if already exists
    if (_createdEcus.containsKey(address)) {
      return _createdEcus[address];
    }

    // Find SVT entry if available
    final svtEntry = _svtData?.ecus
        .where((e) => e.address == address)
        .firstOrNull;

    if (svtEntry != null) {
      return createFromSvtEntry(svtEntry, strategy: strategy);
    }

    // Create basic ECU
    VirtualECU ecu;

    if (_isNbtEvo(ecuName)) {
      ecu = NbtEvoEcu(
        diagAddress: address,
        name: ecuName,
        psdzDataPath: _mappingService.psdzBasePath,
      );
    } else {
      ecu = VirtualECU(diagAddress: address, name: ecuName);
    }

    ecu.vin = _vin;
    ecu.iStep = _iStep;
    if (_faData != null) ecu.loadFA(_faData!);

    _createdEcus[address] = ecu;
    notifyListeners();

    return ecu;
  }

  /// Create all ECUs from SVT
  Future<List<VirtualECU>> createFromSvt(
    SVTData svt, {
    EcuCreationStrategy strategy = EcuCreationStrategy.deep,
  }) async {
    _svtData = svt;
    final created = <VirtualECU>[];

    _statusMessage = 'Creating ${svt.ecus.length} ECUs from SVT...';
    notifyListeners();

    for (final entry in svt.ecus) {
      final ecu = await createFromSvtEntry(entry, strategy: strategy);
      if (ecu != null) {
        created.add(ecu);
      }
    }

    _statusMessage = 'Created ${created.length} ECUs';
    notifyListeners();

    return created;
  }

  /// Create standard vehicle ECUs
  Future<List<VirtualECU>> createStandardVehicle({
    EcuCreationStrategy strategy = EcuCreationStrategy.standard,
  }) async {
    final standardAddresses = [
      0x10, // ZGW
      0x01, // BDC
      0x12, // DME
      0x18, // EGS
      0x2A, // DSC
      0x30, // EPS
      0x40, // CAS
      0x60, // KOMBI
      0x63, // HU_NBT
      0x72, // FEM
      0x6C, // IHKA
      0x80, // AMP
    ];

    final created = <VirtualECU>[];

    for (final address in standardAddresses) {
      final ecu = await createByAddress(address, strategy: strategy);
      if (ecu != null) {
        created.add(ecu);
      }
    }

    return created;
  }

  /// Load deep data from PSDZ/NCD
  Future<void> _loadDeepData(VirtualECU ecu, SVTEcuData svtEntry) async {
    // Find PSDZ mapping for ECU
    final mapping = _mappingService.findEcu(svtEntry.name);

    if (mapping != null) {
      // Load CAFD data
      final cafd = mapping.latestCafd;
      if (cafd?.dataFile != null) {
        final cafdFile = await _ncdCafdLoader.loadCafdFile(cafd!.dataFile!);
        if (cafdFile != null) {
          ecu.loadCAFDData(0x1000, cafdFile.rawData);
          _responseEngine.loadCafdData(
            ecu.diagAddress,
            cafdFile.sgbmId,
            cafdFile.rawData,
          );
        }
      }
    }

    // Load NCD files from backup if available
    final ncdFiles = await _ncdCafdLoader.loadEcuNcdFiles(
      'C:/Data/Backup/${svtEntry.name}',
    );

    for (final ncd in ncdFiles) {
      _responseEngine.loadNcdData(ecu.diagAddress, ncd.sgbmId, ncd.rawData);
    }
  }

  /// Check if ECU is NBT EVO type
  bool _isNbtEvo(String name) {
    final nbtNames = ['HU_NBT', 'HU_MGU', 'NBT', 'MGU', 'HU_ENTRY', 'HU_CIC'];
    return nbtNames.any((n) => name.toUpperCase().contains(n));
  }

  /// Get ECU by address
  VirtualECU? getEcu(int address) => _createdEcus[address];

  /// Get all ECUs as map
  Map<int, VirtualECU> get allEcus => Map.unmodifiable(_createdEcus);

  /// Clear all created ECUs
  void clear() {
    _createdEcus.clear();
    notifyListeners();
  }

  /// Build complete vehicle simulation
  Future<Map<int, VirtualECU>> buildVehicleSimulation({
    required String vin,
    required String iStep,
    FAData? faData,
    SVTData? svtData,
    String? backupPath,
    EcuCreationStrategy strategy = EcuCreationStrategy.deep,
  }) async {
    clear();

    // Set context
    setVehicleContext(vin: vin, iStep: iStep, faData: faData, svtData: svtData);

    // Create ECUs from SVT or standard set
    if (svtData != null && svtData.ecus.isNotEmpty) {
      await createFromSvt(svtData, strategy: strategy);
    } else {
      await createStandardVehicle(strategy: strategy);
    }

    // Load NCD files from backup if path provided
    if (backupPath != null) {
      await _loadBackupNcdFiles(backupPath);
    }

    return allEcus;
  }

  /// Load NCD files from backup folder
  Future<void> _loadBackupNcdFiles(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) return;

      await for (final entity in backupDir.list()) {
        if (entity is Directory) {
          // Each subfolder is an ECU
          final ecuName = entity.path.split(Platform.pathSeparator).last;
          final ecu = _findEcuByName(ecuName);

          if (ecu != null) {
            final ncdFiles = await _ncdCafdLoader.loadEcuNcdFiles(entity.path);
            for (final ncd in ncdFiles) {
              ecu.loadCAFDData(0x1000, ncd.rawData);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading backup NCD files: $e');
    }
  }

  /// Find ECU by name
  VirtualECU? _findEcuByName(String name) {
    final upperName = name.toUpperCase();
    return _createdEcus.values
        .where(
          (e) =>
              e.name.toUpperCase() == upperName ||
              e.name.toUpperCase().contains(upperName),
        )
        .firstOrNull;
  }
}
