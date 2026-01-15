/// Dynamic Response Engine - Real-time UDS Response Generation
/// Generates authentic BMW UDS responses based on SVT/FA/NCD data
///
/// Features:
/// - Dynamic DID generation from vehicle data
/// - CAFD coding response synthesis
/// - SVK building from SGBM parts
/// - Session-aware response handling
/// - Security level management
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library dynamic_response_engine;

import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../virtual_ecu.dart';
import 'deep_ecu_mapping_engine.dart';

/// Response Generation Strategy
enum ResponseStrategy {
  /// Use static pre-defined responses
  static,

  /// Generate dynamic responses from vehicle data
  dynamic,

  /// Use PSDZ CAFD files for coding data
  psdzBased,

  /// Use NCD backup data
  ncdBased,

  /// Hybrid - combine multiple sources
  hybrid,
}

/// Dynamic Response Context
class ResponseContext {
  final int ecuAddress;
  final int session;
  final bool securityUnlocked;
  final String vin;
  final String iStep;
  final FAData? faData;
  final SVTData? svtData;
  final Map<String, Uint8List> ncdData;
  final Map<String, Uint8List> cafdData;

  ResponseContext({
    required this.ecuAddress,
    this.session = 0x01,
    this.securityUnlocked = false,
    this.vin = 'WBA00000000000000',
    this.iStep = 'G030-24-03-550',
    this.faData,
    this.svtData,
    this.ncdData = const {},
    this.cafdData = const {},
  });
}

/// Dynamic Response Engine
class DynamicResponseEngine extends ChangeNotifier {
  final Map<int, EcuResponseGenerator> _generators = {};
  ResponseStrategy _defaultStrategy = ResponseStrategy.hybrid;

  // Cached vehicle data
  String _vin = 'WBA00000000000000';
  String _iStep = 'G030-24-03-550';
  FAData? _faData;
  SVTData? _svtData;
  final Map<int, Map<String, Uint8List>> _ecuNcdData = {};
  final Map<int, Map<String, Uint8List>> _ecuCafdData = {};

  // Getters
  ResponseStrategy get defaultStrategy => _defaultStrategy;
  String get vin => _vin;
  String get iStep => _iStep;

  /// Set response strategy
  set defaultStrategy(ResponseStrategy strategy) {
    _defaultStrategy = strategy;
    notifyListeners();
  }

  /// Load vehicle data for response generation
  void loadVehicleData({
    required String vin,
    required String iStep,
    FAData? faData,
    SVTData? svtData,
  }) {
    _vin = vin;
    _iStep = iStep;
    _faData = faData;
    _svtData = svtData;

    // Reinitialize all generators with new data
    for (final generator in _generators.values) {
      generator.updateContext(
        vin: vin,
        iStep: iStep,
        faData: faData,
        svtData: svtData,
      );
    }

    debugPrint('DynamicResponseEngine: Loaded vehicle $vin');
    notifyListeners();
  }

  /// Load NCD data for ECU
  void loadNcdData(int ecuAddress, String sgbmId, Uint8List data) {
    _ecuNcdData.putIfAbsent(ecuAddress, () => {})[sgbmId] = data;

    final generator = _generators[ecuAddress];
    if (generator != null) {
      generator.addNcdData(sgbmId, data);
    }
  }

  /// Load CAFD data for ECU
  void loadCafdData(int ecuAddress, String sgbmId, Uint8List data) {
    _ecuCafdData.putIfAbsent(ecuAddress, () => {})[sgbmId] = data;

    final generator = _generators[ecuAddress];
    if (generator != null) {
      generator.addCafdData(sgbmId, data);
    }
  }

  /// Get or create generator for ECU
  EcuResponseGenerator getGenerator(int ecuAddress) {
    return _generators.putIfAbsent(ecuAddress, () {
      final info = BmwEcuAddressRegistry.getByAddress(ecuAddress);
      final context = ResponseContext(
        ecuAddress: ecuAddress,
        vin: _vin,
        iStep: _iStep,
        faData: _faData,
        svtData: _svtData,
        ncdData: _ecuNcdData[ecuAddress] ?? {},
        cafdData: _ecuCafdData[ecuAddress] ?? {},
      );

      return EcuResponseGenerator(
        address: ecuAddress,
        name: info?.shortName ?? 'ECU_${ecuAddress.toRadixString(16)}',
        context: context,
        strategy: _defaultStrategy,
      );
    });
  }

  /// Process UDS request through dynamic engine
  Uint8List? processRequest(int ecuAddress, Uint8List request) {
    final generator = getGenerator(ecuAddress);
    return generator.processRequest(request);
  }

  /// Get all active generators
  List<EcuResponseGenerator> get activeGenerators =>
      _generators.values.toList();
}

/// ECU Response Generator - Per-ECU response generation
class EcuResponseGenerator {
  final int address;
  final String name;
  ResponseContext context;
  ResponseStrategy strategy;

  // Internal state
  int _session = 0x01;
  int _securityLevel = 0x00;
  bool _securityUnlocked = false;

  // DID storage
  final Map<int, Uint8List> _dids = {};

  // NCD/CAFD data
  final Map<String, Uint8List> _ncdData = {};
  final Map<String, Uint8List> _cafdData = {};

  // SVK parts
  final List<ECUPart> _svkParts = [];

  EcuResponseGenerator({
    required this.address,
    required this.name,
    required this.context,
    this.strategy = ResponseStrategy.hybrid,
  }) {
    _initializeFromContext();
  }

  /// Initialize DIDs from context
  void _initializeFromContext() {
    // VIN
    _dids[BmwDataIdentifier.vin] = _vinToBytes(context.vin);

    // I-Step
    final iStepBytes = _stringToBytes(context.iStep, 24);
    _dids[BmwDataIdentifier.iStepShipment] = iStepBytes;
    _dids[BmwDataIdentifier.iStepCurrent] = iStepBytes;
    _dids[BmwDataIdentifier.iStepLast] = iStepBytes;

    // Session
    _dids[BmwDataIdentifier.activeDiagSession] = Uint8List.fromList([_session]);

    // ECU Name
    _dids[BmwDataIdentifier.ecuPartNumber] = _stringToBytes(name, 20);
    _dids[BmwDataIdentifier.systemName] = _stringToBytes(name, 24);

    // Manufacturing date
    _dids[BmwDataIdentifier.manufacturingDate] = Uint8List.fromList([
      0x20, 0x24, 0x01, 0x15, // 2024-01-15
    ]);

    // Load from FA if available
    if (context.faData != null) {
      _loadFromFA(context.faData!);
    }

    // Load from SVT if available
    if (context.svtData != null) {
      _loadFromSVT(context.svtData!);
    }

    // Load NCD/CAFD data
    _ncdData.addAll(context.ncdData);
    _cafdData.addAll(context.cafdData);

    // Build SVK
    _buildSvk();
  }

  /// Update context with new vehicle data
  void updateContext({
    String? vin,
    String? iStep,
    FAData? faData,
    SVTData? svtData,
  }) {
    if (vin != null) {
      context = ResponseContext(
        ecuAddress: context.ecuAddress,
        session: context.session,
        securityUnlocked: context.securityUnlocked,
        vin: vin,
        iStep: iStep ?? context.iStep,
        faData: faData ?? context.faData,
        svtData: svtData ?? context.svtData,
        ncdData: context.ncdData,
        cafdData: context.cafdData,
      );
      _initializeFromContext();
    }
  }

  /// Add NCD data
  void addNcdData(String sgbmId, Uint8List data) {
    _ncdData[sgbmId] = data;
    _processCodingData(sgbmId, data);
  }

  /// Add CAFD data
  void addCafdData(String sgbmId, Uint8List data) {
    _cafdData[sgbmId] = data;
    _processCodingData(sgbmId, data);
  }

  /// Process coding data and extract DIDs
  void _processCodingData(String sgbmId, Uint8List data) {
    // Parse CAFD/NCD binary for coding values
    // Format depends on ECU type, but generally:
    // - Bytes 0-3: Header
    // - Bytes 4+: Coding blocks

    if (data.length < 4) return;

    // Store as main coding DID
    _dids[BmwDataIdentifier.codingData] = data;

    // Parse SGBM ID for SVK entry
    final part = ECUPart.fromSgbmId(sgbmId);
    if (part != null && !_svkParts.any((p) => p.sgbmId == sgbmId)) {
      _svkParts.add(part);
      _buildSvk();
    }
  }

  /// Load data from FA
  void _loadFromFA(FAData fa) {
    // VIN
    _dids[BmwDataIdentifier.vin] = _vinToBytes(fa.vin);

    // FA binary for VCM
    _dids[BmwDataIdentifier.vcmFaData] = fa.toBinaryVCM();
    _dids[BmwDataIdentifier.faData] = fa.toBinaryVCM();

    // VCM status
    _dids[BmwDataIdentifier.vcmStatus] = Uint8List.fromList([0x01]);
    _dids[BmwDataIdentifier.vcmBackupStatus] = Uint8List.fromList([0x01]);
    _dids[BmwDataIdentifier.vcmMasterStatus] = Uint8List.fromList([0x01]);
  }

  /// Load data from SVT
  void _loadFromSVT(SVTData svt) {
    // Find this ECU in SVT
    final ecuData = svt.ecus.where((e) => e.address == address).firstOrNull;
    if (ecuData == null) return;

    // Build SVK from parts
    for (final part in ecuData.parts) {
      final ecuPart = ECUPart.fromSgbmId(part.sgbmId ?? '');
      if (ecuPart != null) {
        _svkParts.add(ecuPart);
      }
    }

    _buildSvk();
  }

  /// Build SVK (Software Version Block)
  void _buildSvk() {
    if (_svkParts.isEmpty) {
      // Default SVK with zero parts
      _dids[BmwDataIdentifier.svkCurrent] = Uint8List.fromList([0x00]);
      _dids[BmwDataIdentifier.svkBackup] = Uint8List.fromList([0x00]);
      return;
    }

    // SVK format:
    // 1 byte: Number of parts
    // For each part: 11 bytes (4 process class + 4 ID + 3 version)
    final svkData = <int>[];
    svkData.add(_svkParts.length & 0xFF);

    for (final part in _svkParts) {
      svkData.addAll(part.toBytes());
    }

    final svk = Uint8List.fromList(svkData);
    _dids[BmwDataIdentifier.svkCurrent] = svk;
    _dids[BmwDataIdentifier.svkBackup] = svk;
  }

  /// Process UDS request
  Uint8List? processRequest(Uint8List request) {
    if (request.isEmpty) return null;

    final serviceId = request[0];

    switch (serviceId) {
      case UdsServiceId.diagnosticSessionControl:
        return _handleSessionControl(request);

      case UdsServiceId.readDataByIdentifier:
        return _handleReadDid(request);

      case UdsServiceId.testerPresent:
        return _handleTesterPresent(request);

      case UdsServiceId.securityAccess:
        return _handleSecurityAccess(request);

      case UdsServiceId.ecuReset:
        return _handleEcuReset(request);

      case UdsServiceId.readDtc:
        return _handleReadDtc(request);

      case UdsServiceId.clearDtc:
        return _handleClearDtc(request);

      case UdsServiceId.writeDataByIdentifier:
        return _handleWriteDid(request);

      case UdsServiceId.routineControl:
        return _handleRoutineControl(request);

      case UdsServiceId.communicationControl:
        return _handleCommunicationControl(request);

      case UdsServiceId.controlDtcSetting:
        return _handleControlDtcSetting(request);

      default:
        return _negativeResponse(serviceId, UdsNrc.serviceNotSupported);
    }
  }

  // === UDS Service Handlers ===

  Uint8List _handleSessionControl(Uint8List request) {
    if (request.length < 2) {
      return _negativeResponse(
        UdsServiceId.diagnosticSessionControl,
        UdsNrc.incorrectMessageLengthOrFormat,
      );
    }

    final sessionType = request[1] & 0x7F;
    _session = sessionType;
    _dids[BmwDataIdentifier.activeDiagSession] = Uint8List.fromList([
      sessionType,
    ]);

    // P2 timing values
    return Uint8List.fromList([
      UdsServiceId.diagnosticSessionControl + 0x40,
      sessionType,
      0x00, 0x19, // P2 = 25ms
      0x01, 0xF4, // P2* = 500ms
    ]);
  }

  Uint8List _handleReadDid(Uint8List request) {
    if (request.length < 3) {
      return _negativeResponse(
        UdsServiceId.readDataByIdentifier,
        UdsNrc.incorrectMessageLengthOrFormat,
      );
    }

    final response = <int>[UdsServiceId.readDataByIdentifier + 0x40];
    bool anyFound = false;

    // Process all requested DIDs (2 bytes each)
    for (int i = 1; i < request.length - 1; i += 2) {
      final did = (request[i] << 8) | request[i + 1];

      // Try to get DID data
      Uint8List? data = _dids[did];

      // If not found, try dynamic generation
      if (data == null && strategy != ResponseStrategy.static) {
        data = _generateDynamicDid(did);
      }

      if (data != null) {
        response.add((did >> 8) & 0xFF);
        response.add(did & 0xFF);
        response.addAll(data);
        anyFound = true;
      }
    }

    if (!anyFound) {
      return _negativeResponse(
        UdsServiceId.readDataByIdentifier,
        UdsNrc.requestOutOfRange,
      );
    }

    return Uint8List.fromList(response);
  }

  /// Generate dynamic DID based on context
  Uint8List? _generateDynamicDid(int did) {
    // Try NCD-based generation
    if (strategy == ResponseStrategy.ncdBased ||
        strategy == ResponseStrategy.hybrid) {
      final ncdDid = _generateFromNcd(did);
      if (ncdDid != null) return ncdDid;
    }

    // Try CAFD-based generation
    if (strategy == ResponseStrategy.psdzBased ||
        strategy == ResponseStrategy.hybrid) {
      final cafdDid = _generateFromCafd(did);
      if (cafdDid != null) return cafdDid;
    }

    // Default generation for common DIDs
    return _generateDefaultDid(did);
  }

  Uint8List? _generateFromNcd(int did) {
    // NCD files contain coding data at specific offsets
    // DID 0x1000+ typically maps to coding blocks
    if (did >= 0x1000 && did < 0x2000 && _ncdData.isNotEmpty) {
      final offset = (did - 0x1000) * 32;
      for (final data in _ncdData.values) {
        if (data.length > offset + 32) {
          return Uint8List.fromList(data.sublist(offset, offset + 32));
        }
      }
    }
    return null;
  }

  Uint8List? _generateFromCafd(int did) {
    // CAFD files have structured coding data
    if (did >= 0x1000 && did < 0x2000 && _cafdData.isNotEmpty) {
      final offset = (did - 0x1000) * 32;
      for (final data in _cafdData.values) {
        if (data.length > offset + 32) {
          return Uint8List.fromList(data.sublist(offset, offset + 32));
        }
      }
    }
    return null;
  }

  Uint8List? _generateDefaultDid(int did) {
    // Generate sensible defaults for common DIDs
    switch (did) {
      case 0xF186: // Active session
        return Uint8List.fromList([_session]);

      case 0xF18B: // Manufacturing date
        return Uint8List.fromList([0x20, 0x24, 0x03, 0x15]);

      case 0xF1A0: // Manufacturer
        return _stringToBytes('BMW', 16);

      case 0xF18A: // Supplier
        return _stringToBytes('BOSCH', 16);

      default:
        return null;
    }
  }

  Uint8List _handleTesterPresent(Uint8List request) {
    final subFunction = request.length > 1 ? request[1] & 0x7F : 0x00;
    return Uint8List.fromList([UdsServiceId.testerPresent + 0x40, subFunction]);
  }

  Uint8List _handleSecurityAccess(Uint8List request) {
    if (request.length < 2) {
      return _negativeResponse(
        UdsServiceId.securityAccess,
        UdsNrc.incorrectMessageLengthOrFormat,
      );
    }

    final level = request[1];

    // Request seed (odd levels)
    if (level % 2 == 1) {
      _securityLevel = level;
      // Generate pseudo-random seed
      final seed = _generateSecuritySeed(level);
      return Uint8List.fromList([
        UdsServiceId.securityAccess + 0x40,
        level,
        ...seed,
      ]);
    }

    // Send key (even levels) - always accept for simulation
    _securityUnlocked = true;
    _securityLevel = level;
    return Uint8List.fromList([UdsServiceId.securityAccess + 0x40, level]);
  }

  Uint8List _generateSecuritySeed(int level) {
    // Generate deterministic seed based on address and level
    final base = (address << 8) | level;
    return Uint8List.fromList([
      (base >> 24) & 0xFF,
      (base >> 16) & 0xFF,
      (base >> 8) & 0xFF,
      base & 0xFF,
    ]);
  }

  Uint8List _handleEcuReset(Uint8List request) {
    final resetType = request.length > 1 ? request[1] : 0x01;

    // Reset session state
    _session = 0x01;
    _securityUnlocked = false;
    _dids[BmwDataIdentifier.activeDiagSession] = Uint8List.fromList([0x01]);

    return Uint8List.fromList([UdsServiceId.ecuReset + 0x40, resetType]);
  }

  Uint8List _handleReadDtc(Uint8List request) {
    if (request.length < 2) {
      return _negativeResponse(
        UdsServiceId.readDtc,
        UdsNrc.incorrectMessageLengthOrFormat,
      );
    }

    final subFunction = request[1];

    switch (subFunction) {
      case 0x01: // Report number of DTCs by status mask
        return Uint8List.fromList([
          UdsServiceId.readDtc + 0x40,
          subFunction,
          0xFF, // Status availability mask
          0x00, // High byte count
          0x00, // Low byte count
        ]);

      case 0x02: // Report DTC by status mask
        return Uint8List.fromList([
          UdsServiceId.readDtc + 0x40,
          subFunction,
          0xFF, // Status availability mask
          // No DTCs
        ]);

      case 0x06: // Report DTC extended record
        return Uint8List.fromList([
          UdsServiceId.readDtc + 0x40,
          subFunction,
          // No extended data
        ]);

      default:
        return Uint8List.fromList([UdsServiceId.readDtc + 0x40, subFunction]);
    }
  }

  Uint8List _handleClearDtc(Uint8List request) {
    return Uint8List.fromList([UdsServiceId.clearDtc + 0x40]);
  }

  Uint8List _handleWriteDid(Uint8List request) {
    if (request.length < 4) {
      return _negativeResponse(
        UdsServiceId.writeDataByIdentifier,
        UdsNrc.incorrectMessageLengthOrFormat,
      );
    }

    final did = (request[1] << 8) | request[2];

    // Check security for protected DIDs
    if (_isProtectedDid(did) && !_securityUnlocked) {
      return _negativeResponse(
        UdsServiceId.writeDataByIdentifier,
        UdsNrc.securityAccessDenied,
      );
    }

    final data = Uint8List.fromList(request.sublist(3));
    _dids[did] = data;

    return Uint8List.fromList([
      UdsServiceId.writeDataByIdentifier + 0x40,
      (did >> 8) & 0xFF,
      did & 0xFF,
    ]);
  }

  bool _isProtectedDid(int did) {
    // DIDs that require security access
    return did >= 0x1000 && did < 0x2000; // Coding DIDs
  }

  Uint8List _handleRoutineControl(Uint8List request) {
    if (request.length < 4) {
      return _negativeResponse(
        UdsServiceId.routineControl,
        UdsNrc.incorrectMessageLengthOrFormat,
      );
    }

    final subFunction = request[1];
    final routineId = (request[2] << 8) | request[3];

    // Common routines
    switch (routineId) {
      case 0xFF00: // Erase memory
      case 0xFF01: // Check programming dependencies
      case 0x0203: // Check programming preconditions
        return Uint8List.fromList([
          UdsServiceId.routineControl + 0x40,
          subFunction,
          (routineId >> 8) & 0xFF,
          routineId & 0xFF,
          0x00, // Status: OK
        ]);

      default:
        return Uint8List.fromList([
          UdsServiceId.routineControl + 0x40,
          subFunction,
          (routineId >> 8) & 0xFF,
          routineId & 0xFF,
          0x00,
        ]);
    }
  }

  Uint8List _handleCommunicationControl(Uint8List request) {
    final subFunction = request.length > 1 ? request[1] : 0x00;
    return Uint8List.fromList([
      UdsServiceId.communicationControl + 0x40,
      subFunction,
    ]);
  }

  Uint8List _handleControlDtcSetting(Uint8List request) {
    final subFunction = request.length > 1 ? request[1] : 0x00;
    return Uint8List.fromList([
      UdsServiceId.controlDtcSetting + 0x40,
      subFunction,
    ]);
  }

  // === Utility Methods ===

  Uint8List _negativeResponse(int serviceId, int nrc) {
    return Uint8List.fromList([UdsServiceId.negativeResponse, serviceId, nrc]);
  }

  Uint8List _vinToBytes(String vin) {
    return Uint8List.fromList(
      vin.padRight(17, '\x00').substring(0, 17).codeUnits,
    );
  }

  Uint8List _stringToBytes(String str, int length) {
    return Uint8List.fromList(
      str.padRight(length, '\x00').substring(0, length).codeUnits,
    );
  }
}
