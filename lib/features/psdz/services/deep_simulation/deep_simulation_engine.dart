/// Deep Simulation Engine - Complete BMW ECU Simulation System
/// Integrates all deep simulation components for E-Sys/ISTA+ compatibility
///
/// This is the main entry point for the deep simulation system.
/// It combines:
/// - PSDZ Mapping for CAFD/SWFL files
/// - Deep ECU Mapping for address registry
/// - Dynamic Response Engine for UDS handling
/// - NCD/CAFD Loader for coding data
/// - PSDZ ECU Factory for ECU creation
/// - Live Streaming Service for FA/SVT
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library deep_simulation_engine;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../virtual_ecu.dart';
import '../nbt_evo_ecu.dart';
import 'psdz_mapping_service.dart';
import 'deep_ecu_mapping_engine.dart';
import 'dynamic_response_engine.dart';
import 'ncd_cafd_loader.dart';
import 'psdz_ecu_factory.dart';
import 'live_streaming_service.dart';

export 'psdz_mapping_service.dart';
export 'deep_ecu_mapping_engine.dart';
export 'dynamic_response_engine.dart';
export 'ncd_cafd_loader.dart';
export 'psdz_ecu_factory.dart';
export 'live_streaming_service.dart';

/// Simulation Mode
enum SimulationMode {
  /// Basic mode - minimal responses
  basic,

  /// Standard mode - common DIDs and services
  standard,

  /// Deep mode - full PSDZ/NCD integration
  deep,

  /// Live mode - real-time streaming
  live,
}

/// Deep Simulation Engine
class DeepSimulationEngine extends ChangeNotifier {
  // Sub-services
  late final PsdzMappingService _mappingService;
  late final DeepEcuMappingEngine _ecuMappingEngine;
  late final DynamicResponseEngine _responseEngine;
  late final NcdCafdLoader _ncdCafdLoader;
  late final PsdzEcuFactory _ecuFactory;
  late final LiveStreamingService _streamingService;

  // ECU storage
  final Map<int, VirtualECU> _ecus = {};

  // Configuration
  String _psdzPath = 'C:/Data/psdzdata';
  String _backupPath = 'C:/Data/Backup';
  SimulationMode _mode = SimulationMode.deep;

  // State
  bool _isInitialized = false;
  bool _isRunning = false;
  String _statusMessage = 'Not initialized';

  // Vehicle context
  String _vin = 'WBA00000000000000';
  String _iStep = 'G030-24-03-550';
  String _series = 'G30';
  FAData? _faData;
  SVTData? _svtData;

  // Statistics
  int _totalRequests = 0;
  int _totalResponses = 0;
  DateTime? _startTime;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  String get statusMessage => _statusMessage;
  String get vin => _vin;
  String get iStep => _iStep;
  String get series => _series;
  SimulationMode get mode => _mode;
  int get ecuCount => _ecus.length;
  int get totalRequests => _totalRequests;
  int get totalResponses => _totalResponses;

  // Service access
  PsdzMappingService get mappingService => _mappingService;
  DeepEcuMappingEngine get ecuMappingEngine => _ecuMappingEngine;
  DynamicResponseEngine get responseEngine => _responseEngine;
  NcdCafdLoader get ncdCafdLoader => _ncdCafdLoader;
  PsdzEcuFactory get ecuFactory => _ecuFactory;
  LiveStreamingService get streamingService => _streamingService;

  /// Constructor
  DeepSimulationEngine({String? psdzPath, String? backupPath}) {
    if (psdzPath != null) _psdzPath = psdzPath;
    if (backupPath != null) _backupPath = backupPath;

    _initializeServices();
  }

  /// Initialize all sub-services
  void _initializeServices() {
    _mappingService = PsdzMappingService();
    _mappingService.psdzBasePath = _psdzPath;

    _ecuMappingEngine = DeepEcuMappingEngine();
    _responseEngine = DynamicResponseEngine();
    _ncdCafdLoader = NcdCafdLoader();
    _ncdCafdLoader.psdzPath = _psdzPath;
    _ncdCafdLoader.backupPath = _backupPath;

    _ecuFactory = PsdzEcuFactory(
      mappingService: _mappingService,
      ncdCafdLoader: _ncdCafdLoader,
      responseEngine: _responseEngine,
    );

    _streamingService = LiveStreamingService();
  }

  /// Initialize the simulation engine
  Future<void> initialize() async {
    _statusMessage = 'Initializing Deep Simulation Engine...';
    notifyListeners();

    try {
      // Initialize ECU mapping
      _ecuMappingEngine.initializeProfiles();

      // Index PSDZ mappings
      await _mappingService.indexMappings();

      // Initialize ECU factory
      await _ecuFactory.initialize();

      _isInitialized = true;
      _statusMessage =
          'Engine initialized - ${_mappingService.totalMappings} mappings, '
          '${_mappingService.totalCafdFiles} CAFD files';

      debugPrint('DeepSimulationEngine: $_statusMessage');
    } catch (e) {
      _statusMessage = 'Initialization error: $e';
      debugPrint('DeepSimulationEngine Error: $e');
    }

    notifyListeners();
  }

  /// Set simulation mode
  set mode(SimulationMode newMode) {
    _mode = newMode;

    // Update response strategy based on mode
    switch (newMode) {
      case SimulationMode.basic:
        _responseEngine.defaultStrategy = ResponseStrategy.static;
        break;
      case SimulationMode.standard:
        _responseEngine.defaultStrategy = ResponseStrategy.dynamic;
        break;
      case SimulationMode.deep:
        _responseEngine.defaultStrategy = ResponseStrategy.hybrid;
        break;
      case SimulationMode.live:
        _responseEngine.defaultStrategy = ResponseStrategy.hybrid;
        _streamingService.startStreaming();
        break;
    }

    notifyListeners();
  }

  /// Load vehicle for simulation
  Future<void> loadVehicle({
    required String vin,
    required String iStep,
    String? series,
    FAData? faData,
    SVTData? svtData,
    String? backupPath,
  }) async {
    _statusMessage = 'Loading vehicle $vin...';
    notifyListeners();

    try {
      _vin = vin;
      _iStep = iStep;
      _series = series ?? 'G30';
      _faData = faData;
      _svtData = svtData;

      // Update response engine with vehicle data
      _responseEngine.loadVehicleData(
        vin: vin,
        iStep: iStep,
        faData: faData,
        svtData: svtData,
      );

      // Build ECUs from vehicle data
      final ecus = await _ecuFactory.buildVehicleSimulation(
        vin: vin,
        iStep: iStep,
        faData: faData,
        svtData: svtData,
        backupPath: backupPath ?? _backupPath,
        strategy: _mode == SimulationMode.deep
            ? EcuCreationStrategy.deep
            : EcuCreationStrategy.standard,
      );

      _ecus.clear();
      _ecus.addAll(ecus);

      // Register with streaming service
      _streamingService.loadVehicle(
        vin: vin,
        iStep: iStep,
        series: series,
        faData: faData,
        svtData: svtData,
      );
      _streamingService.registerEcus(_ecus);

      _statusMessage = 'Vehicle loaded: ${_ecus.length} ECUs';
      debugPrint('DeepSimulationEngine: $_statusMessage');
    } catch (e) {
      _statusMessage = 'Load error: $e';
      debugPrint('DeepSimulationEngine Error: $e');
    }

    notifyListeners();
  }

  /// Load vehicle from backup folder
  Future<void> loadFromBackup(String backupFolderPath) async {
    _statusMessage = 'Loading from backup...';
    notifyListeners();

    try {
      final backupDir = Directory(backupFolderPath);
      if (!await backupDir.exists()) {
        throw Exception('Backup folder not found');
      }

      // Look for FA.xml
      final faFile = File('$backupFolderPath/FA.xml');
      FAData? faData;
      if (await faFile.exists()) {
        faData = FAData();
        faData.loadFromXml(await faFile.readAsString());
      }

      // Look for SVT_ECU.xml
      final svtFile = File('$backupFolderPath/SVT_ECU.xml');
      SVTData? svtData;
      if (await svtFile.exists()) {
        svtData = SVTData();
        svtData.loadFromXml(await svtFile.readAsString());
      }

      // Extract VIN and I-Step
      final vin = faData?.vin ?? 'WBA00000000000000';
      final iStep = svtData?.iStep ?? 'G030-24-03-550';

      // Load vehicle
      await loadVehicle(
        vin: vin,
        iStep: iStep,
        series: faData?.series,
        faData: faData,
        svtData: svtData,
        backupPath: backupFolderPath,
      );
    } catch (e) {
      _statusMessage = 'Backup load error: $e';
      debugPrint('DeepSimulationEngine Error: $e');
      notifyListeners();
    }
  }

  /// Start simulation
  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _startTime = DateTime.now();
    _statusMessage = 'Simulation running - ${_ecus.length} ECUs';

    if (_mode == SimulationMode.live) {
      _streamingService.startStreaming();
    }

    notifyListeners();
  }

  /// Stop simulation
  void stop() {
    _isRunning = false;
    _streamingService.stopStreaming();
    _statusMessage = 'Simulation stopped';
    notifyListeners();
  }

  /// Process UDS request
  Uint8List? processRequest(int ecuAddress, Uint8List request) {
    if (!_isRunning) return null;

    _totalRequests++;

    // Get ECU
    final ecu = _ecus[ecuAddress];
    if (ecu == null) {
      // Try response engine fallback
      return _responseEngine.processRequest(ecuAddress, request);
    }

    // Process through ECU
    final response = ecu.processRequest(request);
    if (response != null) {
      _totalResponses++;
    }

    return response;
  }

  /// Get ECU by address
  VirtualECU? getEcu(int address) => _ecus[address];

  /// Get all ECUs
  Map<int, VirtualECU> get allEcus => Map.unmodifiable(_ecus);

  /// Get ECU addresses
  List<int> get ecuAddresses => _ecus.keys.toList()..sort();

  /// Add ECU
  void addEcu(VirtualECU ecu) {
    _ecus[ecu.diagAddress] = ecu;
    _streamingService.registerEcu(ecu);
    notifyListeners();
  }

  /// Remove ECU
  void removeEcu(int address) {
    _ecus.remove(address);
    _streamingService.unregisterEcu(address);
    notifyListeners();
  }

  /// Get simulation statistics
  Map<String, dynamic> get statistics => {
    'mode': _mode.name,
    'isRunning': _isRunning,
    'isInitialized': _isInitialized,
    'vin': _vin,
    'iStep': _iStep,
    'series': _series,
    'ecuCount': _ecus.length,
    'totalRequests': _totalRequests,
    'totalResponses': _totalResponses,
    'uptime': _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0,
    'mappings': _mappingService.totalMappings,
    'cafdFiles': _mappingService.totalCafdFiles,
    'ncdFiles': _ncdCafdLoader.loadedNcdCount,
    'streaming': _streamingService.statistics,
  };

  /// Clear all data
  void clear() {
    stop();
    _ecus.clear();
    _ecuFactory.clear();
    _streamingService.clear();
    _faData = null;
    _svtData = null;
    _totalRequests = 0;
    _totalResponses = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _streamingService.dispose();
    super.dispose();
  }
}

/// Deep Simulation Provider Factory
class DeepSimulationProviderFactory {
  static DeepSimulationEngine create({String? psdzPath, String? backupPath}) {
    return DeepSimulationEngine(psdzPath: psdzPath, backupPath: backupPath);
  }

  /// Create and initialize
  static Future<DeepSimulationEngine> createAndInitialize({
    String? psdzPath,
    String? backupPath,
  }) async {
    final engine = create(psdzPath: psdzPath, backupPath: backupPath);
    await engine.initialize();
    return engine;
  }
}
