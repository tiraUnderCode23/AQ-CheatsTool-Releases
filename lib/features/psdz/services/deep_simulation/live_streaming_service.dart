/// Live FA/SVT Streaming Service - Real-time vehicle data streaming
/// Provides live FA and SVT data to simulated ECUs for E-Sys compatibility
///
/// Features:
/// - Real-time FA streaming (VCM format)
/// - SVT/SVK live updates
/// - I-Step synchronization across ECUs
/// - VIN propagation
/// - Coding data distribution
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library live_streaming_service;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../virtual_ecu.dart';
import 'deep_ecu_mapping_engine.dart';

/// Streaming State
enum StreamingState { idle, preparing, streaming, paused, error }

/// Streaming Event Type
enum StreamingEventType {
  vehicleLoaded,
  faUpdated,
  svtUpdated,
  ecuAdded,
  ecuRemoved,
  codingChanged,
  iStepChanged,
  vinChanged,
  error,
}

/// Streaming Event
class StreamingEvent {
  final StreamingEventType type;
  final String message;
  final dynamic data;
  final DateTime timestamp;

  StreamingEvent({required this.type, required this.message, this.data})
    : timestamp = DateTime.now();

  @override
  String toString() => '[$type] $message';
}

/// Live FA/SVT Streaming Service
class LiveStreamingService extends ChangeNotifier {
  // State
  StreamingState _state = StreamingState.idle;
  String _statusMessage = 'Ready';
  bool _isStreaming = false;

  // Vehicle data
  String _vin = 'WBA00000000000000';
  String _iStep = 'G030-24-03-550';
  String _series = 'G30';
  FAData? _faData;
  SVTData? _svtData;

  // ECU registry
  final Map<int, VirtualECU> _ecus = {};

  // Event stream
  final _eventController = StreamController<StreamingEvent>.broadcast();

  // Streaming timer
  Timer? _streamingTimer;
  Duration _updateInterval = const Duration(milliseconds: 100);

  // Statistics
  int _totalUpdates = 0;
  int _faReadCount = 0;
  int _svtReadCount = 0;
  DateTime? _streamingStartTime;

  // Getters
  StreamingState get state => _state;
  String get statusMessage => _statusMessage;
  bool get isStreaming => _isStreaming;
  String get vin => _vin;
  String get iStep => _iStep;
  String get series => _series;
  FAData? get faData => _faData;
  SVTData? get svtData => _svtData;
  Stream<StreamingEvent> get eventStream => _eventController.stream;
  int get ecuCount => _ecus.length;
  int get totalUpdates => _totalUpdates;
  Duration get updateInterval => _updateInterval;

  /// Set update interval
  set updateInterval(Duration interval) {
    _updateInterval = interval;
    if (_isStreaming) {
      _restartStreaming();
    }
  }

  /// Load vehicle for streaming
  Future<void> loadVehicle({
    required String vin,
    required String iStep,
    String? series,
    FAData? faData,
    SVTData? svtData,
  }) async {
    _state = StreamingState.preparing;
    _statusMessage = 'Loading vehicle $vin...';
    notifyListeners();

    try {
      _vin = vin;
      _iStep = iStep;
      _series = series ?? _extractSeries(vin);
      _faData = faData;
      _svtData = svtData;

      // Update all registered ECUs
      await _propagateVehicleData();

      _state = StreamingState.idle;
      _statusMessage = 'Vehicle loaded: $vin';

      _emitEvent(
        StreamingEvent(
          type: StreamingEventType.vehicleLoaded,
          message: 'Vehicle $vin loaded',
          data: {'vin': vin, 'iStep': iStep},
        ),
      );
    } catch (e) {
      _state = StreamingState.error;
      _statusMessage = 'Load error: $e';

      _emitEvent(
        StreamingEvent(
          type: StreamingEventType.error,
          message: 'Failed to load vehicle: $e',
        ),
      );
    }

    notifyListeners();
  }

  /// Register ECU for streaming
  void registerEcu(VirtualECU ecu) {
    _ecus[ecu.diagAddress] = ecu;

    // Apply current vehicle data
    ecu.vin = _vin;
    ecu.iStep = _iStep;
    if (_faData != null) ecu.loadFA(_faData!);
    if (_svtData != null) ecu.loadSVT(_svtData!);

    _emitEvent(
      StreamingEvent(
        type: StreamingEventType.ecuAdded,
        message: 'ECU registered: ${ecu.name}',
        data: ecu.diagAddress,
      ),
    );

    notifyListeners();
  }

  /// Unregister ECU
  void unregisterEcu(int address) {
    final ecu = _ecus.remove(address);
    if (ecu != null) {
      _emitEvent(
        StreamingEvent(
          type: StreamingEventType.ecuRemoved,
          message: 'ECU unregistered: ${ecu.name}',
          data: address,
        ),
      );
      notifyListeners();
    }
  }

  /// Register multiple ECUs
  void registerEcus(Map<int, VirtualECU> ecus) {
    for (final ecu in ecus.values) {
      registerEcu(ecu);
    }
  }

  /// Start streaming
  void startStreaming() {
    if (_isStreaming) return;

    _isStreaming = true;
    _state = StreamingState.streaming;
    _streamingStartTime = DateTime.now();
    _statusMessage = 'Streaming to ${_ecus.length} ECUs...';

    _streamingTimer = Timer.periodic(_updateInterval, _onStreamingTick);

    notifyListeners();
  }

  /// Stop streaming
  void stopStreaming() {
    _streamingTimer?.cancel();
    _streamingTimer = null;
    _isStreaming = false;
    _state = StreamingState.idle;
    _statusMessage = 'Streaming stopped';

    notifyListeners();
  }

  /// Pause streaming
  void pauseStreaming() {
    if (!_isStreaming) return;

    _streamingTimer?.cancel();
    _state = StreamingState.paused;
    _statusMessage = 'Streaming paused';

    notifyListeners();
  }

  /// Resume streaming
  void resumeStreaming() {
    if (_state != StreamingState.paused) return;

    _state = StreamingState.streaming;
    _streamingTimer = Timer.periodic(_updateInterval, _onStreamingTick);
    _statusMessage = 'Streaming resumed';

    notifyListeners();
  }

  /// Streaming tick handler
  void _onStreamingTick(Timer timer) {
    _totalUpdates++;

    // Update session DIDs if needed
    for (final ecu in _ecus.values) {
      // Keep session alive
      ecu.setDID(
        BmwDataIdentifier.activeDiagSession,
        Uint8List.fromList([ecu.session]),
      );
    }
  }

  /// Restart streaming with new interval
  void _restartStreaming() {
    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(_updateInterval, _onStreamingTick);
  }

  /// Update FA data
  Future<void> updateFA(FAData fa) async {
    _faData = fa;
    _vin = fa.vin;
    _series = fa.series;

    // Propagate to all ECUs
    for (final ecu in _ecus.values) {
      ecu.vin = _vin;
      ecu.loadFA(fa);
    }

    _emitEvent(
      StreamingEvent(
        type: StreamingEventType.faUpdated,
        message: 'FA updated: ${fa.vin}',
        data: fa,
      ),
    );

    notifyListeners();
  }

  /// Update SVT data
  Future<void> updateSVT(SVTData svt) async {
    _svtData = svt;

    // Propagate to all ECUs
    for (final ecu in _ecus.values) {
      ecu.loadSVT(svt);
    }

    _emitEvent(
      StreamingEvent(
        type: StreamingEventType.svtUpdated,
        message: 'SVT updated: ${svt.ecus.length} ECUs',
        data: svt,
      ),
    );

    notifyListeners();
  }

  /// Update I-Step
  void updateIStep(String istep) {
    _iStep = istep;

    // Propagate to all ECUs
    final istepBytes = Uint8List.fromList(
      istep.padRight(24, '\x00').substring(0, 24).codeUnits,
    );

    for (final ecu in _ecus.values) {
      ecu.iStep = istep;
      ecu.setDID(BmwDataIdentifier.iStepShipment, istepBytes);
      ecu.setDID(BmwDataIdentifier.iStepCurrent, istepBytes);
      ecu.setDID(BmwDataIdentifier.iStepLast, istepBytes);
    }

    _emitEvent(
      StreamingEvent(
        type: StreamingEventType.iStepChanged,
        message: 'I-Step updated: $istep',
        data: istep,
      ),
    );

    notifyListeners();
  }

  /// Update VIN
  void updateVIN(String vin) {
    if (vin.length != 17) return;

    _vin = vin;
    _series = _extractSeries(vin);

    // Propagate to all ECUs
    final vinBytes = Uint8List.fromList(vin.codeUnits);

    for (final ecu in _ecus.values) {
      ecu.vin = vin;
      ecu.setDID(BmwDataIdentifier.vin, vinBytes);
    }

    _emitEvent(
      StreamingEvent(
        type: StreamingEventType.vinChanged,
        message: 'VIN updated: $vin',
        data: vin,
      ),
    );

    notifyListeners();
  }

  /// Get FA binary for VCM read
  Uint8List? getFABinary() {
    if (_faData == null) return null;
    _faReadCount++;
    return _faData!.toBinaryVCM();
  }

  /// Get SVK binary for ECU
  Uint8List? getSVKBinary(int ecuAddress) {
    final ecu = _ecus[ecuAddress];
    if (ecu == null) return null;
    _svtReadCount++;
    return ecu.getDID(BmwDataIdentifier.svkCurrent);
  }

  /// Propagate vehicle data to all ECUs
  Future<void> _propagateVehicleData() async {
    for (final ecu in _ecus.values) {
      ecu.vin = _vin;
      ecu.iStep = _iStep;

      if (_faData != null) {
        ecu.loadFA(_faData!);
      }

      if (_svtData != null) {
        ecu.loadSVT(_svtData!);
      }
    }
  }

  /// Extract series from VIN
  String _extractSeries(String vin) {
    // BMW VIN position 4-7 contains series info
    if (vin.length >= 7) {
      final wmi = vin.substring(0, 3);
      if (wmi == 'WBA' || wmi == 'WBS') {
        // Extract model code
        final modelCode = vin.substring(3, 7);
        return _decodeModelSeries(modelCode);
      }
    }
    return 'G30'; // Default
  }

  /// Decode model series from VIN
  String _decodeModelSeries(String code) {
    // Common BMW model codes
    final seriesMap = {
      'JG': 'G30', // 5 Series
      'JH': 'G30', // 5 Series LCI
      'JA': 'G20', // 3 Series
      'JB': 'G20', // 3 Series LCI
      'JM': 'G05', // X5
      'JN': 'G06', // X6
      'KA': 'G07', // X7
      'MJ': 'G11', // 7 Series
      'MK': 'G12', // 7 Series LWB
      'BJ': 'F30', // 3 Series
      'BK': 'F31', // 3 Series Touring
      'CL': 'F10', // 5 Series
      'CM': 'F11', // 5 Series Touring
    };

    return seriesMap[code.substring(0, 2)] ?? 'G30';
  }

  /// Emit streaming event
  void _emitEvent(StreamingEvent event) {
    _eventController.add(event);
  }

  /// Get ECU by address
  VirtualECU? getEcu(int address) => _ecus[address];

  /// Get all ECUs
  Map<int, VirtualECU> get allEcus => Map.unmodifiable(_ecus);

  /// Get streaming statistics
  Map<String, dynamic> get statistics => {
    'state': _state.name,
    'isStreaming': _isStreaming,
    'ecuCount': _ecus.length,
    'totalUpdates': _totalUpdates,
    'faReadCount': _faReadCount,
    'svtReadCount': _svtReadCount,
    'updateInterval': _updateInterval.inMilliseconds,
    'uptime': _streamingStartTime != null
        ? DateTime.now().difference(_streamingStartTime!).inSeconds
        : 0,
  };

  /// Clear all data
  void clear() {
    stopStreaming();
    _ecus.clear();
    _faData = null;
    _svtData = null;
    _totalUpdates = 0;
    _faReadCount = 0;
    _svtReadCount = 0;
    _streamingStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopStreaming();
    _eventController.close();
    super.dispose();
  }
}

/// VCM (Vehicle Configuration Management) Response Builder
class VcmResponseBuilder {
  /// Build VCM FA read response (for DID 0x1769)
  static Uint8List buildFaReadResponse(FAData fa) {
    return fa.toBinaryVCM();
  }

  /// Build VCM status response (for DID 0xF1D0)
  static Uint8List buildVcmStatus({
    bool faStored = true,
    bool backupExists = true,
    bool masterExists = true,
  }) {
    return Uint8List.fromList([
      faStored ? 0x01 : 0x00,
      backupExists ? 0x01 : 0x00,
      masterExists ? 0x01 : 0x00,
    ]);
  }

  /// Build I-Step response
  static Uint8List buildIStepResponse(String istep) {
    return Uint8List.fromList(
      istep.padRight(24, '\x00').substring(0, 24).codeUnits,
    );
  }

  /// Build SVK response
  static Uint8List buildSvkResponse(List<ECUPart> parts) {
    final data = <int>[parts.length & 0xFF];

    for (final part in parts) {
      data.addAll(part.toBytes());
    }

    return Uint8List.fromList(data);
  }
}
