import 'dart:typed_data';

/// Lightweight, extensible registry for UDS response mapping.
///
/// Motivation: keep `VirtualECU` defaults intact, but allow adding/overriding
/// responses in a structured way (ECU + service + DID/routine).
///
/// This mirrors common DoIP simulators that expose handler/registry APIs.

/// Minimal ECU surface that handlers may need.
abstract class UdsEcu {
  int get diagAddress;
  String get name;

  /// Current diagnostic session type (UDS 0x10).
  int get sessionType;

  /// Current security access level (UDS 0x27).
  int get securityLevel;

  /// A per-connection/per-ECU bag of state for handlers (seed counters, flashing state...).
  Map<String, Object?> get udsSession;

  String get vin;
  String get iStep;

  Uint8List? getDID(int did);
  void setDID(int did, Uint8List data);
}

typedef UdsServiceHandler = Uint8List? Function(UdsEcu ecu, Uint8List request);
typedef UdsDidHandler =
    Uint8List? Function(UdsEcu ecu, int did, Uint8List request);
typedef UdsRoutineHandler =
    Uint8List? Function(
      UdsEcu ecu,
      int subFunction,
      int routineId,
      Uint8List routineData,
      Uint8List request,
    );

class _DidRangeHandler {
  final int start;
  final int end;
  final UdsDidHandler handler;

  const _DidRangeHandler({
    required this.start,
    required this.end,
    required this.handler,
  });

  bool matches(int did) => did >= start && did <= end;
}

/// Registry for mapping/overriding UDS responses.
class UdsMappingRegistry {
  final Map<int, UdsServiceHandler> _serviceHandlers = {};
  final Map<int, UdsDidHandler> _didHandlers = {};
  final List<_DidRangeHandler> _didRangeHandlers = [];
  final Map<int, UdsRoutineHandler> _routineHandlers = {};

  void clear() {
    _serviceHandlers.clear();
    _didHandlers.clear();
    _didRangeHandlers.clear();
    _routineHandlers.clear();
  }

  /// Register a full service handler (e.g. override $27 security access).
  void registerService(int serviceId, UdsServiceHandler handler) {
    _serviceHandlers[serviceId & 0xFF] = handler;
  }

  void unregisterService(int serviceId) {
    _serviceHandlers.remove(serviceId & 0xFF);
  }

  /// Register a DID handler for $22 ReadDataByIdentifier.
  void registerDid(int did, UdsDidHandler handler) {
    _didHandlers[did & 0xFFFF] = handler;
  }

  void unregisterDid(int did) {
    _didHandlers.remove(did & 0xFFFF);
  }

  /// Register a DID range handler, useful for e.g. CAFD blocks 0x1000-0x1FFF.
  void registerDidRange(int startDid, int endDid, UdsDidHandler handler) {
    final start = startDid & 0xFFFF;
    final end = endDid & 0xFFFF;
    _didRangeHandlers.add(
      _DidRangeHandler(
        start: start < end ? start : end,
        end: start < end ? end : start,
        handler: handler,
      ),
    );
  }

  /// Register a routine handler for $31 RoutineControl.
  void registerRoutine(int routineId, UdsRoutineHandler handler) {
    _routineHandlers[routineId & 0xFFFF] = handler;
  }

  void unregisterRoutine(int routineId) {
    _routineHandlers.remove(routineId & 0xFFFF);
  }

  /// Attempt to handle a full service. Return null to fall back to default ECU logic.
  Uint8List? handleService(UdsEcu ecu, int serviceId, Uint8List request) {
    final handler = _serviceHandlers[serviceId & 0xFF];
    return handler?.call(ecu, request);
  }

  /// Attempt to handle a DID. Return null to fall back to default ECU logic.
  Uint8List? handleDid(UdsEcu ecu, int did, Uint8List request) {
    final id = did & 0xFFFF;

    final exact = _didHandlers[id];
    if (exact != null) {
      final r = exact(ecu, id, request);
      if (r != null) return r;
    }

    for (final entry in _didRangeHandlers) {
      if (!entry.matches(id)) continue;
      final r = entry.handler(ecu, id, request);
      if (r != null) return r;
    }

    return null;
  }

  /// Attempt to handle a routine. Return null to fall back to default ECU logic.
  Uint8List? handleRoutine(
    UdsEcu ecu,
    int subFunction,
    int routineId,
    Uint8List routineData,
    Uint8List request,
  ) {
    final handler = _routineHandlers[routineId & 0xFFFF];
    return handler?.call(
      ecu,
      subFunction,
      routineId & 0xFFFF,
      routineData,
      request,
    );
  }
}
