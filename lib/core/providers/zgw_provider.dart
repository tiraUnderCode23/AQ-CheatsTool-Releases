import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// BMW ZGW Protocol Constants - Matching Python NBTevoTool_Integrated.py
class ZGWProtocol {
  // Protocol Ports
  static const int udpBroadcastPort = 6811;
  static const int tcpDiagnosticPort = 6801;
  static const int sshPort = 22;

  // ECU Addresses
  static const int ecuZGW = 0x10;
  static const int ecuHU = 0x63; // HeadUnit NBT/NBTevo
  static const int ecuRSE = 0x26;
  static const int ecuTester = 0xF4; // External Tester (required for BMW ENET)
  static const int ecuTesterAlt = 0xF1;

  // Magic Packets
  static final Uint8List helloZGW =
      Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x11]);

  /// Build HSFZ diagnostic message
  /// Format: [Length:4][0x00][0x01][Source:1][Target:1][Payload]
  static Uint8List buildDiagnosticMessage(
      int source, int target, Uint8List udsData) {
    final length = udsData.length + 4; // 4 bytes for type + source + target
    final header = ByteData(4);
    header.setUint32(0, length, Endian.big);

    final message = Uint8List(8 + udsData.length);
    message.setRange(0, 4, header.buffer.asUint8List());
    message[4] = 0x00; // Payload type request
    message[5] = 0x01; // Frame type
    message[6] = source;
    message[7] = target;
    message.setRange(8, 8 + udsData.length, udsData);

    return message;
  }

  /// Parse HSFZ response: returns (payloadType, source, target, udsData)
  static ({int payloadType, int source, int target, Uint8List udsData})
      parseDoIPResponse(Uint8List data) {
    if (data.length < 8) {
      return (payloadType: 0, source: 0, target: 0, udsData: Uint8List(0));
    }

    final byteData = ByteData.sublistView(data);
    final length = byteData.getUint32(0, Endian.big);

    if (data.length >= 8) {
      final payloadType = data[4];
      final source = data[6];
      final target = data[7];
      final udsData = length > 4 ? data.sublist(8, 4 + length) : Uint8List(0);

      return (
        payloadType: payloadType,
        source: source,
        target: target,
        udsData: udsData
      );
    }

    return (payloadType: 0, source: 0, target: 0, udsData: Uint8List(0));
  }
}

/// UDS Commands Library for NBT/NBTevo - Matching Python
class UDSCommands {
  // Diagnostic Session Control (0x10)
  static Uint8List sessionDefault() => Uint8List.fromList([0x10, 0x01]);
  static Uint8List sessionProgramming() => Uint8List.fromList([0x10, 0x02]);
  static Uint8List sessionExtended() => Uint8List.fromList([0x10, 0x03]);
  static Uint8List sessionCoding() => Uint8List.fromList([0x10, 0x41]);
  static Uint8List sessionSWT() => Uint8List.fromList([0x10, 0x42]);

  // ECU Reset (0x11)
  static Uint8List ecuHardReset() => Uint8List.fromList([0x11, 0x01]);
  static Uint8List ecuSoftReset() => Uint8List.fromList([0x11, 0x03]);

  // Clear DTC (0x14)
  static Uint8List clearAllDTC() =>
      Uint8List.fromList([0x14, 0xFF, 0xFF, 0xFF]);

  // Read DTC Info (0x19)
  static Uint8List readDTCByStatus({int mask = 0xFF}) =>
      Uint8List.fromList([0x19, 0x02, mask]);
  static Uint8List readDTCSupported() => Uint8List.fromList([0x19, 0x0A]);

  // Read Data By Identifier (0x22)
  static Uint8List readVIN() => Uint8List.fromList([0x22, 0xF1, 0x90]);
  static Uint8List readECUSerial() => Uint8List.fromList([0x22, 0xF1, 0x8C]);
  static Uint8List readHWVersion() => Uint8List.fromList([0x22, 0xF1, 0x91]);
  static Uint8List readSWVersion() => Uint8List.fromList([0x22, 0xF1, 0x95]);
  static Uint8List readSGBDIndex() => Uint8List.fromList([0x22, 0xF1, 0x50]);
  static Uint8List readCurrentSVK() => Uint8List.fromList([0x22, 0xF1, 0x01]);
  static Uint8List readIPConfig() => Uint8List.fromList([0x22, 0x17, 0x2A]);
  static Uint8List readBootloaderVersion() =>
      Uint8List.fromList([0x22, 0xF1, 0x80]);
  static Uint8List readDiagVersion() => Uint8List.fromList([0x22, 0xF1, 0x11]);
  static Uint8List readECUSupplier() => Uint8List.fromList([0x22, 0xF1, 0x8A]);
  static Uint8List readECUManufDate() => Uint8List.fromList([0x22, 0xF1, 0x8B]);
  static Uint8List readApplicationSW() =>
      Uint8List.fromList([0x22, 0xF1, 0x88]);
  static Uint8List readCalibrationID() =>
      Uint8List.fromList([0x22, 0xF1, 0x93]);
  static Uint8List readActiveSession() =>
      Uint8List.fromList([0x22, 0xF1, 0x86]);

  // Write Data By Identifier (0x2E)
  static Uint8List writeVIN(String vin) {
    if (vin.length != 17) {
      throw ArgumentError('VIN must be exactly 17 characters');
    }
    return Uint8List.fromList([0x2E, 0xF1, 0x90, ...vin.codeUnits]);
  }

  static Uint8List writeDataByIdentifier(
      int didHigh, int didLow, List<int> data) {
    return Uint8List.fromList([0x2E, didHigh, didLow, ...data]);
  }

  // Security Access (0x27)
  static Uint8List securityAccessRequestSeed(int level) =>
      Uint8List.fromList([0x27, level]);

  static Uint8List securityAccessSendKey(int level, Uint8List key) =>
      Uint8List.fromList([0x27, level + 1, ...key]);

  // Routine Control (0x31) - Used for Tool32 Jobs
  static Uint8List routineControlStart(int routineIdHigh, int routineIdLow,
          [List<int>? optionRecord]) =>
      Uint8List.fromList(
          [0x31, 0x01, routineIdHigh, routineIdLow, ...?optionRecord]);

  static Uint8List routineControlStop(int routineIdHigh, int routineIdLow,
          [List<int>? optionRecord]) =>
      Uint8List.fromList(
          [0x31, 0x02, routineIdHigh, routineIdLow, ...?optionRecord]);

  static Uint8List routineControlRequestResults(
          int routineIdHigh, int routineIdLow) =>
      Uint8List.fromList([0x31, 0x03, routineIdHigh, routineIdLow]);

  // Communication Control (0x28)
  static Uint8List communicationControlEnable() =>
      Uint8List.fromList([0x28, 0x00, 0x03]);

  static Uint8List communicationControlDisable() =>
      Uint8List.fromList([0x28, 0x03, 0x03]);

  // Control DTC Setting (0x85)
  static Uint8List dtcSettingOn() => Uint8List.fromList([0x85, 0x01]);
  static Uint8List dtcSettingOff() => Uint8List.fromList([0x85, 0x02]);

  // Tester Present (0x3E)
  static Uint8List testerPresent() => Uint8List.fromList([0x3E, 0x00]);
}

/// BMW ZGW (Central Gateway) Discovery and Communication Provider
/// Based on Python NBTevoTool_Integrated.py logic
class ZGWProvider extends ChangeNotifier {
  // Connection state
  Socket? _socket;
  bool _isSearching = false;
  bool _isConnected = false;
  String? _zgwIp;
  String? _localIp; // Local IP to bind for connection
  String? _huIp;
  String? _vin;
  String? _macAddress;
  String _searchProgress = '';
  final List<Map<String, dynamic>> _foundCars = [];
  final List<String> _logMessages = [];
  String? _lastError;

  // ECU addresses for communication
  final int _testerAddress = ZGWProtocol.ecuTester;
  int _targetEcu = ZGWProtocol.ecuHU;

  // Getters
  bool get isSearching => _isSearching;
  bool get isConnected => _isConnected;
  String get zgwIp => _zgwIp ?? '';
  String get huIp => _huIp ?? '';
  String get vin => _vin ?? '';
  String? get macAddress => _macAddress;
  String get searchProgress => _searchProgress;
  List<Map<String, dynamic>> get foundCars => _foundCars;
  List<String> get logMessages => _logMessages;
  String? get lastError => _lastError;

  /// Add log message
  void _log(String message, {String level = 'info'}) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    final prefix = {
          'info': 'ℹ️',
          'success': '✅',
          'warning': '⚠️',
          'error': '❌',
          'blue': '📡',
          'green': '✅',
          'red': '❌',
          'orange': '⚠️',
        }[level] ??
        'ℹ️';

    _logMessages.add('[$timestamp] $prefix $message');

    // Keep only last 100 messages
    if (_logMessages.length > 100) {
      _logMessages.removeAt(0);
    }

    notifyListeners();
  }

  /// Public method to add log messages from UI
  void addLog(String message, String level) {
    _log(message, level: level);
  }

  /// Clear logs
  void clearLogs() {
    _logMessages.clear();
    notifyListeners();
  }

  /// Calculate broadcast IP from host and netmask
  String _getBroadcastIp(String host, String mask) {
    try {
      final hostParts = host.split('.').map(int.parse).toList();
      final maskParts = mask.split('.').map(int.parse).toList();

      final broadcastParts = <int>[];
      for (int i = 0; i < 4; i++) {
        broadcastParts.add(hostParts[i] | (~maskParts[i] & 0xFF));
      }

      return broadcastParts.join('.');
    } catch (e) {
      return '255.255.255.255';
    }
  }

  /// Start ZGW discovery - matching Python search_zgw logic
  Future<void> startSearch() async {
    if (_isSearching) return;

    _isSearching = true;
    _foundCars.clear();
    _lastError = null;
    _searchProgress = 'Initializing...';
    _log('📡 Starting ZGW search...', level: 'blue');
    notifyListeners();

    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list();
      _log('Found ${interfaces.length} network interfaces', level: 'info');

      for (var interface in interfaces) {
        if (!_isSearching) break;

        for (var addr in interface.addresses) {
          if (!_isSearching) break;
          if (addr.type != InternetAddressType.IPv4) continue;
          if (addr.address.startsWith('127.')) continue;

          final ip = addr.address;

          // Try to get netmask (default to 255.255.255.0)
          const netmask = '255.255.255.0';
          final broadcast = _getBroadcastIp(ip, netmask);

          _searchProgress = 'Scanning ${interface.name}: $ip';
          _log('📡 Searching on ${interface.name}: $ip -> $broadcast',
              level: 'info');
          notifyListeners();

          // Send UDP broadcast and wait for response
          await _sendUdpBroadcast(ip, broadcast);

          // Also try 255.255.255.255 broadcast
          if (broadcast != '255.255.255.255') {
            await _sendUdpBroadcast(ip, '255.255.255.255');
          }
        }
      }

      if (_foundCars.isEmpty) {
        _searchProgress = 'No BMW found';
        _log('⚠️ No ZGW found. Check network connection.', level: 'warning');
        _log('💡 Make sure you are connected to BMW OBD2 ENET adapter.',
            level: 'info');
      } else {
        _searchProgress = 'Found ${_foundCars.length} BMW car(s)';
        _log('✅ Discovery complete: ${_foundCars.length} BMW car(s) found',
            level: 'success');
      }
    } catch (e) {
      _lastError = e.toString();
      _searchProgress = 'Error occurred';
      _log('❌ Discovery error: $e', level: 'error');
    }

    _isSearching = false;
    notifyListeners();
  }

  /// Send UDP broadcast to discover ZGW - matching Python logic
  Future<void> _sendUdpBroadcast(String localIp, String broadcastIp) async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress(localIp),
        0,
      );
      socket.broadcastEnabled = true;

      // Send HELLO_ZGW packet
      socket.send(
        ZGWProtocol.helloZGW,
        InternetAddress(broadcastIp),
        ZGWProtocol.udpBroadcastPort,
      );

      // Wait for response with timeout
      bool received = false;
      final completer = Completer<void>();

      final subscription = socket.timeout(
        const Duration(milliseconds: 500),
        onTimeout: (sink) {
          if (!received) sink.close();
        },
      ).listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) {
              received = true;
              _processZgwResponse(
                  datagram.data, datagram.address.address, localIp);
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for completion or timeout
      await Future.any([
        completer.future,
        Future.delayed(const Duration(milliseconds: 600)),
      ]);

      await subscription.cancel();
      socket.close();
    } catch (e) {
      // Timeout or error - normal if no ZGW found on this interface
    }
  }

  /// Process ZGW response - matching Python pattern
  void _processZgwResponse(Uint8List data, String senderIp, String localIp) {
    try {
      final response = String.fromCharCodes(data);

      // Parse BMW ZGW response format: DIAGADRxxxBMWMACxxxBMWVINxxx
      final diagMatch =
          RegExp(r'DIAGADR(.*)BMWMAC(.*)BMWVIN(.*)').firstMatch(response);

      if (diagMatch != null) {
        final diagAddr = diagMatch.group(1)?.trim() ?? '';
        final mac = diagMatch.group(2)?.trim() ?? '';
        final extractedVin = diagMatch.group(3)?.trim() ?? '';

        // Check if already found
        if (!_foundCars.any((car) => car['ip'] == senderIp)) {
          final carInfo = {
            'ip': senderIp,
            'localIp': localIp, // Save local IP for binding
            'vin': extractedVin,
            'mac': mac,
            'diagAddr': diagAddr,
            'discoveredAt': DateTime.now().toIso8601String(),
          };

          _foundCars.add(carInfo);
          _log('✅ Found ZGW at $senderIp', level: 'success');
          _log('📍 Local IP: $localIp', level: 'info');
          if (extractedVin.isNotEmpty) {
            _log('🚗 VIN: $extractedVin', level: 'success');
          }

          // Auto-select first car
          if (_zgwIp == null) {
            selectCar(carInfo);
          }

          notifyListeners();
        }
      } else {
        // Even without VIN pattern, if we got a response it's a ZGW
        if (!_foundCars.any((car) => car['ip'] == senderIp)) {
          _log('✅ Found ZGW at $senderIp (no VIN in response)',
              level: 'success');

          final carInfo = {
            'ip': senderIp,
            'localIp': localIp,
            'vin': '',
            'mac': '',
            'diagAddr': '',
            'discoveredAt': DateTime.now().toIso8601String(),
          };

          _foundCars.add(carInfo);

          if (_zgwIp == null) {
            selectCar(carInfo);
          }

          notifyListeners();
        }
      }
    } catch (e) {
      _log('Error processing ZGW reply: $e', level: 'error');
    }
  }

  /// Stop ZGW discovery
  void stopSearch() {
    _isSearching = false;
    _log('ZGW discovery stopped', level: 'warning');
    notifyListeners();
  }

  /// Find correct local IP that can reach ZGW - matching Python logic
  Future<String?> _findCorrectLocalIp(String zgwIp) async {
    _log('🔍 Finding correct interface for $zgwIp...', level: 'info');

    // Get all network interfaces
    final interfaces = await NetworkInterface.list();

    // Find 169.254.x.x interfaces (link-local, typical for ENET)
    final candidateIps = <String>[];
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          final ip = addr.address;
          if (ip.startsWith('169.254.')) {
            candidateIps.add(ip);
          }
        }
      }
    }

    // Test each candidate IP to see which can connect to ZGW
    for (var localIp in candidateIps) {
      try {
        final testSocket = await Socket.connect(
          zgwIp,
          ZGWProtocol.tcpDiagnosticPort,
          sourceAddress: InternetAddress(localIp),
          timeout: const Duration(seconds: 2),
        );
        testSocket.close();
        _log('✅ Found working interface: $localIp', level: 'success');
        return localIp;
      } catch (e) {
        // This interface can't reach ZGW
        continue;
      }
    }

    return null;
  }

  /// Connect to ZGW - matching Python connect_to_zgw logic
  Future<bool> connectToZGW(String ip, {int retries = 3}) async {
    // First, find the correct local IP that can reach the ZGW
    final correctLocalIp = await _findCorrectLocalIp(ip);
    if (correctLocalIp != null) {
      _localIp = correctLocalIp;
    }

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        // Close existing connection
        if (_socket != null) {
          try {
            _socket!.close();
          } catch (e) {}
        }

        _log(
            '📡 Connecting to $ip:${ZGWProtocol.tcpDiagnosticPort} (attempt ${attempt + 1}/$retries)...',
            level: 'info');

        // Create socket with optional source address binding
        if (_localIp != null) {
          _socket = await Socket.connect(
            ip,
            ZGWProtocol.tcpDiagnosticPort,
            sourceAddress: InternetAddress(_localIp!),
            timeout: const Duration(seconds: 10),
          );
          _log('📍 Bound to local IP: $_localIp', level: 'info');
        } else {
          _socket = await Socket.connect(
            ip,
            ZGWProtocol.tcpDiagnosticPort,
            timeout: const Duration(seconds: 10),
          );
        }

        _zgwIp = ip;
        _isConnected = true;
        _log('✅ Connected to ZGW at $ip:${ZGWProtocol.tcpDiagnosticPort}',
            level: 'success');
        notifyListeners();
        return true;
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 110 || e.message.contains('timed out')) {
          _log('⏱️ Connection attempt ${attempt + 1} timed out',
              level: 'warning');
        } else {
          _log('❌ Connection attempt ${attempt + 1} failed: $e',
              level: 'error');
        }
        if (attempt < retries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        _log('❌ Connection attempt ${attempt + 1} failed: $e', level: 'error');
        if (attempt < retries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    _isConnected = false;
    _log('❌ Failed to connect after $retries attempts', level: 'error');
    notifyListeners();
    return false;
  }

  /// Select a discovered car
  Future<void> selectCar(Map<String, dynamic> car) async {
    _zgwIp = car['ip'];
    _localIp = car['localIp'];
    _vin = car['vin'];
    _macAddress = car['mac'];

    _log(
        'Selected BMW: ${car['vin'].isNotEmpty ? car['vin'] : 'Unknown VIN'} @ ${car['ip']}',
        level: 'success');

    // Connect to ZGW
    final connected = await connectToZGW(_zgwIp!);

    if (connected) {
      // Try to read VIN if not already known
      if (_vin == null || _vin!.isEmpty) {
        final vinResult = await readVin();
        if (vinResult != null) {
          _vin = vinResult;
          _log('🚗 VIN: $_vin', level: 'success');
        }
      }

      // Try to get Head Unit IP
      await _findHuIp();
    }

    notifyListeners();
  }

  /// Send UDS command and receive response - matching Python send_uds
  Future<Uint8List?> sendUDS(Uint8List udsData) async {
    if (!_isConnected || _socket == null) {
      _log('❌ Not connected', level: 'error');
      return null;
    }

    try {
      // Build DoIP diagnostic message
      final message = ZGWProtocol.buildDiagnosticMessage(
        _testerAddress,
        _targetEcu,
        udsData,
      );

      _log(
          'TX → ${udsData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase()}',
          level: 'info');
      _socket!.add(message);

      // Receive response with timeout
      final response = await _socket!.first.timeout(const Duration(seconds: 5));

      if (response.isNotEmpty) {
        final parsed =
            ZGWProtocol.parseDoIPResponse(Uint8List.fromList(response));
        _log(
            'RX ← ${parsed.udsData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase()}',
            level: 'success');
        return parsed.udsData;
      }
    } on TimeoutException {
      _log('⏱️ Response timeout', level: 'warning');
    } catch (e) {
      _log('❌ Error: $e', level: 'error');
    }

    return null;
  }

  /// Find Head Unit IP using UDS ReadDataByIdentifier - matching Python find_hu_ip
  Future<void> _findHuIp() async {
    // Read IP Config: 22 17 2A
    final response = await sendUDS(UDSCommands.readIPConfig());

    if (response != null && response.length >= 7 && response[0] == 0x62) {
      // Response: 62 17 2A IP1 IP2 IP3 IP4 ...
      final ip = '${response[3]}.${response[4]}.${response[5]}.${response[6]}';
      _huIp = ip;
      _log('📡 HeadUnit IP: $ip', level: 'success');
      notifyListeners();
    }
  }

  /// Send UDS command (string or bytes) - public API
  Future<Map<String, dynamic>> sendUdsCommand(String command,
      {String? targetAddress}) async {
    if (_zgwIp == null || !_isConnected) {
      return {'success': false, 'error': 'No ZGW connection'};
    }

    try {
      // Update target ECU if specified
      if (targetAddress != null) {
        _targetEcu = int.parse(targetAddress, radix: 16);
      }

      // Parse command to bytes
      final commandBytes = _parseUdsCommand(command);
      if (commandBytes == null) {
        return {'success': false, 'error': 'Invalid command format'};
      }

      final response = await sendUDS(commandBytes);

      if (response == null) {
        return {'success': false, 'error': 'No response'};
      }

      // Parse response
      final parsed = _parseUdsResponse(response);
      return {
        'success': parsed['positive'],
        'response': parsed['description'],
        'rawData': response
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ')
            .toUpperCase(),
        'data': response,
      };
    } catch (e) {
      _log('Command failed: $e', level: 'error');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Parse UDS command string to bytes
  Uint8List? _parseUdsCommand(String command) {
    try {
      // Named commands
      final namedCommands = {
        'DEFSESS': '10 01',
        'PROGSESS': '10 02',
        'EXTDIAGSESS': '10 03',
        'CODINGSESS': '10 41',
        'SWTSESS': '10 42',
        'HardReset': '11 01',
        'SoftReset': '11 03',
        'ReadVIN': '22 F1 90',
        'ReadIPConfig': '22 17 2A',
        'ReadDTC': '19 02 FF',
        'ClearDTC': '14 FF FF FF',
        'TesterPresent': '3E 00',
      };

      if (namedCommands.containsKey(command)) {
        command = namedCommands[command]!;
      }

      // Parse hex string
      final parts =
          command.split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).toList();
      return Uint8List.fromList(
          parts.map((p) => int.parse(p, radix: 16)).toList());
    } catch (e) {
      return null;
    }
  }

  /// Parse UDS response
  Map<String, dynamic> _parseUdsResponse(Uint8List data) {
    if (data.isEmpty) {
      return {'positive': false, 'description': 'Empty response'};
    }

    final serviceId = data[0];

    // Positive response (service ID + 0x40)
    if (serviceId >= 0x50) {
      final originalService = serviceId - 0x40;
      return {
        'positive': true,
        'description':
            'Positive response for service 0x${originalService.toRadixString(16).toUpperCase()}',
        'service': originalService,
        'data': data.sublist(1),
      };
    }

    // Negative response (0x7F)
    if (serviceId == 0x7F && data.length >= 3) {
      final rejectedService = data[1];
      final nrc = data[2];

      final nrcDescriptions = {
        0x10: 'General reject',
        0x11: 'Service not supported',
        0x12: 'Sub-function not supported',
        0x13: 'Incorrect message length',
        0x14: 'Response too long',
        0x21: 'Busy - repeat request',
        0x22: 'Conditions not correct',
        0x24: 'Request sequence error',
        0x25: 'No response from sub-net',
        0x26: 'Failure prevents execution',
        0x31: 'Request out of range',
        0x33: 'Security access denied',
        0x35: 'Invalid key',
        0x36: 'Exceeded number of attempts',
        0x37: 'Required time delay not expired',
        0x70: 'Upload/download not accepted',
        0x71: 'Transfer data suspended',
        0x72: 'General programming failure',
        0x73: 'Wrong block sequence counter',
        0x78: 'Response pending',
        0x7E: 'Sub-function not supported in active session',
        0x7F: 'Service not supported in active session',
      };

      final nrcDesc = nrcDescriptions[nrc] ??
          'Unknown NRC 0x${nrc.toRadixString(16).toUpperCase()}';

      return {
        'positive': false,
        'description': 'Negative response: $nrcDesc',
        'nrc': nrc,
        'service': rejectedService,
      };
    }

    return {
      'positive': true,
      'description': 'Response received',
      'data': data,
    };
  }

  /// Read VIN from ECU
  Future<String?> readVin() async {
    final response = await sendUDS(UDSCommands.readVIN());

    if (response != null && response.length >= 20 && response[0] == 0x62) {
      // Response: 62 F1 90 [17 bytes VIN]
      final vinBytes = response.sublist(3, 20);
      return String.fromCharCodes(vinBytes).trim();
    }

    return null;
  }

  /// Enter Extended Diagnostic Session
  Future<Map<String, dynamic>> enterExtendedSession() async {
    _log('Entering Extended Diagnostic Session...', level: 'blue');
    final response = await sendUDS(UDSCommands.sessionExtended());
    if (response != null && response[0] == 0x50) {
      return {'success': true, 'response': 'Session activated'};
    }
    return {'success': false, 'error': 'Failed to enter session'};
  }

  /// Reboot Head Unit
  Future<Map<String, dynamic>> rebootHeadUnit() async {
    _log('Sending Hard Reset command...', level: 'blue');
    final response = await sendUDS(UDSCommands.ecuHardReset());
    if (response != null) {
      return {'success': true, 'response': 'Reset command sent'};
    }
    return {'success': false, 'error': 'No response to reset command'};
  }

  /// Send provisioning command for MGU
  Future<Map<String, dynamic>> sendProvisioningCommand(
      String mguType, String command) async {
    _log('Sending $mguType provisioning command: $command', level: 'blue');

    // Parse command (e.g., "c:/MGU;0x03")
    final parts = command.split(';');
    final filePath = parts.isNotEmpty ? parts[0] : '';
    int modeByte = 0x03;

    if (parts.length > 1) {
      final modeStr = parts[1].trim();
      if (modeStr.startsWith('0x')) {
        modeByte = int.parse(modeStr.substring(2), radix: 16);
      }
    }

    // Build Write Data By Identifier command (0x2E F1 99)
    final payload = utf8.encode(filePath);
    final udsData = Uint8List.fromList([
      0x2E,
      0xF1,
      0x99,
      ...payload,
      0x00,
      modeByte,
    ]);

    final response = await sendUDS(udsData);
    if (response != null && response[0] == 0x6E) {
      return {'success': true, 'response': 'Provisioning command accepted'};
    }

    return {'success': false, 'error': 'Provisioning command failed'};
  }

  /// Write VIN to ECU (requires Extended Session)
  Future<Map<String, dynamic>> writeVin(String newVin) async {
    if (newVin.length != 17) {
      return {'success': false, 'error': 'VIN must be exactly 17 characters'};
    }

    _log('Writing VIN: $newVin', level: 'blue');

    // First enter extended session
    final sessionResult = await enterExtendedSession();
    if (!sessionResult['success']) {
      return {'success': false, 'error': 'Failed to enter extended session'};
    }

    // Send Write VIN command
    try {
      final udsData = UDSCommands.writeVIN(newVin);
      final response = await sendUDS(udsData);

      if (response != null && response[0] == 0x6E) {
        _log('✅ VIN written successfully: $newVin', level: 'success');
        return {'success': true, 'response': 'VIN written: $newVin'};
      } else if (response != null && response[0] == 0x7F) {
        final nrc = response.length > 2 ? response[2] : 0;
        final nrcMsg = _getNrcDescription(nrc);
        _log('❌ VIN write rejected: $nrcMsg', level: 'error');
        return {'success': false, 'error': 'VIN write rejected: $nrcMsg'};
      }

      return {'success': false, 'error': 'Unexpected response'};
    } catch (e) {
      _log('❌ VIN write error: $e', level: 'error');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get NRC description
  String _getNrcDescription(int nrc) {
    final nrcDescriptions = {
      0x10: 'General reject',
      0x11: 'Service not supported',
      0x12: 'Sub-function not supported',
      0x13: 'Incorrect message length',
      0x22: 'Conditions not correct',
      0x31: 'Request out of range',
      0x33: 'Security access denied',
      0x35: 'Invalid key',
      0x72: 'General programming failure',
      0x78: 'Response pending',
    };
    return nrcDescriptions[nrc] ?? 'Unknown NRC 0x${nrc.toRadixString(16)}';
  }

  /// Read comprehensive ECU info
  Future<Map<String, String>> readEcuInfo() async {
    final info = <String, String>{};

    _log('Reading ECU information...', level: 'blue');

    // Read VIN
    final vinResponse = await sendUDS(UDSCommands.readVIN());
    if (vinResponse != null &&
        vinResponse.length >= 20 &&
        vinResponse[0] == 0x62) {
      info['VIN'] = String.fromCharCodes(vinResponse.sublist(3, 20)).trim();
    }

    // Read ECU Serial Number
    final serialResponse = await sendUDS(UDSCommands.readECUSerial());
    if (serialResponse != null &&
        serialResponse.length > 3 &&
        serialResponse[0] == 0x62) {
      info['Serial'] = String.fromCharCodes(serialResponse.sublist(3)).trim();
    }

    // Read Hardware Version
    final hwResponse = await sendUDS(UDSCommands.readHWVersion());
    if (hwResponse != null && hwResponse.length > 3 && hwResponse[0] == 0x62) {
      info['HW Version'] = String.fromCharCodes(hwResponse.sublist(3)).trim();
    }

    // Read Software Version
    final swResponse = await sendUDS(UDSCommands.readSWVersion());
    if (swResponse != null && swResponse.length > 3 && swResponse[0] == 0x62) {
      info['SW Version'] = String.fromCharCodes(swResponse.sublist(3)).trim();
    }

    // Read Bootloader Version
    final blResponse = await sendUDS(UDSCommands.readBootloaderVersion());
    if (blResponse != null && blResponse.length > 3 && blResponse[0] == 0x62) {
      info['Bootloader'] = String.fromCharCodes(blResponse.sublist(3)).trim();
    }

    // Read SGBD Index
    final sgbdResponse = await sendUDS(UDSCommands.readSGBDIndex());
    if (sgbdResponse != null &&
        sgbdResponse.length > 3 &&
        sgbdResponse[0] == 0x62) {
      info['SGBD'] = String.fromCharCodes(sgbdResponse.sublist(3)).trim();
    }

    // Read ECU Supplier
    final supplierResponse = await sendUDS(UDSCommands.readECUSupplier());
    if (supplierResponse != null &&
        supplierResponse.length > 3 &&
        supplierResponse[0] == 0x62) {
      info['Supplier'] =
          String.fromCharCodes(supplierResponse.sublist(3)).trim();
    }

    // Read IP Config
    final ipResponse = await sendUDS(UDSCommands.readIPConfig());
    if (ipResponse != null && ipResponse.length >= 7 && ipResponse[0] == 0x62) {
      info['IP Address'] =
          '${ipResponse[3]}.${ipResponse[4]}.${ipResponse[5]}.${ipResponse[6]}';
    }

    _log('✅ ECU info read: ${info.length} parameters', level: 'success');
    return info;
  }

  /// Execute Tool32-style Job with Arguments
  /// This mimics the PyDiabas/Tool32 job execution
  Future<Map<String, dynamic>> executeJob({
    required String jobName,
    required String argument,
    String? ecuAddress,
  }) async {
    _log('Executing Job: $jobName with argument: $argument', level: 'blue');

    // Update target ECU if specified
    if (ecuAddress != null) {
      try {
        _targetEcu = int.parse(ecuAddress.replaceFirst('0x', ''), radix: 16);
      } catch (e) {
        // Keep current target
      }
    }

    // Map job names to UDS sequences
    final jobResults = <String, dynamic>{
      'jobName': jobName,
      'argument': argument,
      'steps': <Map<String, dynamic>>[],
    };

    try {
      // Known Jobs mapping
      if (jobName.toLowerCase() == 'steuern_provisioning_data') {
        // This is the MGU provisioning job
        // Step 1: Enter Extended Session
        final step1 = await enterExtendedSession();
        jobResults['steps'].add({
          'step': 'Enter Extended Session (10 03)',
          'result': step1,
        });

        if (!step1['success']) {
          return {
            'success': false,
            'error': 'Failed to enter extended session',
            'details': jobResults
          };
        }

        // Step 2: Send provisioning command
        final step2 = await sendProvisioningCommand(jobName, argument);
        jobResults['steps'].add({
          'step': 'Send Provisioning Data',
          'result': step2,
        });

        // Step 3: Hard Reset
        await Future.delayed(const Duration(milliseconds: 500));
        final step3 = await rebootHeadUnit();
        jobResults['steps'].add({
          'step': 'Hard Reset (11 01)',
          'result': step3,
        });

        return {
          'success': step2['success'],
          'response':
              step2['success'] ? 'Job executed successfully' : 'Job failed',
          'details': jobResults
        };
      } else if (jobName.toLowerCase().contains('fs_lesen')) {
        // Read fault storage
        final response = await sendUDS(UDSCommands.readDTCByStatus());
        jobResults['steps'].add({
          'step': 'Read DTC (19 02 FF)',
          'result': {'success': response != null, 'data': response},
        });
        return {'success': response != null, 'details': jobResults};
      } else if (jobName.toLowerCase().contains('fs_loeschen')) {
        // Clear fault storage
        final response = await sendUDS(UDSCommands.clearAllDTC());
        jobResults['steps'].add({
          'step': 'Clear DTC (14 FF FF FF)',
          'result': {'success': response != null},
        });
        return {'success': response != null, 'details': jobResults};
      } else if (jobName.toLowerCase().contains('ident')) {
        // Read identification
        final info = await readEcuInfo();
        return {'success': true, 'details': info};
      } else {
        // Generic job: parse argument as raw UDS command
        final cmdBytes = _parseUdsCommand(argument);
        if (cmdBytes != null) {
          final response = await sendUDS(cmdBytes);
          jobResults['steps'].add({
            'step': 'Raw command: $argument',
            'result': {
              'success': response != null,
              'data': response
                  ?.map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(' ')
            },
          });
          return {'success': response != null, 'details': jobResults};
        }

        return {
          'success': false,
          'error': 'Unknown job: $jobName',
          'details': jobResults
        };
      }
    } catch (e) {
      _log('❌ Job execution error: $e', level: 'error');
      return {'success': false, 'error': e.toString(), 'details': jobResults};
    }
  }

  /// Execute complete MGU unlock sequence
  /// This performs the full VIN swap and provisioning in one operation
  Future<Map<String, dynamic>> executeMguUnlock({
    required String mguVin,
    required String mguCommand,
    required String mguJob,
    required String originalVin,
  }) async {
    final results = <String, dynamic>{
      'steps': <Map<String, dynamic>>[],
      'success': false,
    };

    _log('🔓 Starting MGU Unlock sequence...', level: 'blue');
    _log('📋 Target VIN: $mguVin', level: 'info');
    _log('📋 Original VIN: $originalVin', level: 'info');
    _log('📋 Provisioning command: $mguCommand', level: 'info');

    try {
      // Step 1: Enter Extended Session
      _log('Step 1: Entering Extended Session (10 03)...', level: 'blue');
      final sessionResult = await enterExtendedSession();
      results['steps'].add({
        'step': '1. Enter Extended Session',
        'command': '10 03',
        'success': sessionResult['success'],
        'response': sessionResult['response'] ?? sessionResult['error'],
      });

      if (!sessionResult['success']) {
        _log('❌ Failed to enter extended session', level: 'error');
        return results;
      }
      _log('✅ Extended session active', level: 'success');

      // Step 2: Write MGU VIN (unlock VIN)
      _log('Step 2: Writing MGU VIN ($mguVin)...', level: 'blue');
      final writeVinResult = await _writeVinDirect(mguVin);
      results['steps'].add({
        'step': '2. Write MGU VIN',
        'command': '2E F1 90 + VIN bytes',
        'success': writeVinResult['success'],
        'response': writeVinResult['response'] ?? writeVinResult['error'],
      });

      if (writeVinResult['success']) {
        _log('✅ MGU VIN written successfully', level: 'success');
      } else {
        _log('⚠️ VIN write may have failed, continuing...', level: 'warning');
      }

      // Step 3: Hard Reset to apply VIN change
      _log('Step 3: Hard Reset (11 01)...', level: 'blue');
      final resetResult = await rebootHeadUnit();
      results['steps'].add({
        'step': '3. Hard Reset',
        'command': '11 01',
        'success': resetResult['success'],
        'response': resetResult['response'] ?? resetResult['error'],
      });

      // Wait for ECU to restart (5 seconds minimum for MGU)
      _log('⏳ Waiting 5 seconds for ECU restart...', level: 'info');
      await Future.delayed(const Duration(seconds: 5));

      // Step 4: Reconnect
      _log('Step 4: Reconnecting to ZGW...', level: 'blue');
      bool reconnected = false;
      if (_zgwIp != null) {
        // Retry connection up to 3 times
        for (int attempt = 1; attempt <= 3; attempt++) {
          _log('  Connection attempt $attempt/3...', level: 'info');
          reconnected = await connectToZGW(_zgwIp!);
          if (reconnected) break;
          await Future.delayed(const Duration(seconds: 2));
        }

        results['steps'].add({
          'step': '4. Reconnect',
          'success': reconnected,
          'response': reconnected
              ? 'Connected'
              : 'Failed to reconnect after 3 attempts',
        });

        if (!reconnected) {
          _log('❌ Failed to reconnect after 3 attempts', level: 'error');
          return results;
        }
        _log('✅ Reconnected to ZGW', level: 'success');
      }

      // Step 5: Enter Extended Session again
      _log('Step 5: Entering Extended Session again...', level: 'blue');
      await enterExtendedSession();

      // Step 6: Execute Provisioning Job (the actual unlock command)
      _log('Step 6: Executing Provisioning Job...', level: 'blue');
      _log('  Job: $mguJob', level: 'info');
      _log('  Command: $mguCommand', level: 'info');

      final provResult = await sendProvisioningCommand(mguJob, mguCommand);
      results['steps'].add({
        'step': '6. Execute Provisioning',
        'command': mguCommand,
        'job': mguJob,
        'success': provResult['success'],
        'response': provResult['response'] ?? provResult['error'],
      });

      if (provResult['success']) {
        _log('✅ Provisioning command accepted', level: 'success');
      } else {
        _log('⚠️ Provisioning command may have failed', level: 'warning');
      }

      // Wait for provisioning to complete
      _log('⏳ Waiting 2 seconds for provisioning...', level: 'info');
      await Future.delayed(const Duration(seconds: 2));

      // Step 7: Restore Original VIN
      _log('Step 7: Restoring Original VIN ($originalVin)...', level: 'blue');

      // Re-enter extended session
      await enterExtendedSession();

      final restoreResult = await _writeVinDirect(originalVin);
      results['steps'].add({
        'step': '7. Restore Original VIN',
        'command': '2E F1 90 + VIN bytes',
        'success': restoreResult['success'],
        'response': restoreResult['response'] ?? restoreResult['error'],
      });

      if (restoreResult['success']) {
        _log('✅ Original VIN restored successfully', level: 'success');
      } else {
        _log('⚠️ VIN restoration may have failed - IMPORTANT: Check manually!',
            level: 'warning');
      }

      // Step 8: Final Reset
      _log('Step 8: Final Reset...', level: 'blue');
      await rebootHeadUnit();
      results['steps'].add({
        'step': '8. Final Reset',
        'command': '11 01',
        'success': true,
        'response': 'Reset sent',
      });

      results['success'] = true;
      _log('🎉 MGU Unlock sequence completed successfully!', level: 'success');
      _log('💡 Wait 5 minutes before using the car to let the ECU stabilize.',
          level: 'info');
      return results;
    } catch (e) {
      _log('❌ MGU Unlock error: $e', level: 'error');
      results['error'] = e.toString();
      return results;
    }
  }

  /// Direct VIN write without session management
  Future<Map<String, dynamic>> _writeVinDirect(String vin) async {
    if (vin.length != 17) {
      return {'success': false, 'error': 'VIN must be 17 characters'};
    }

    try {
      final udsData = UDSCommands.writeVIN(vin);
      final response = await sendUDS(udsData);

      if (response != null && response[0] == 0x6E) {
        return {'success': true, 'response': 'VIN written'};
      } else if (response != null && response[0] == 0x7F) {
        final nrc = response.length > 2 ? response[2] : 0;
        return {'success': false, 'error': _getNrcDescription(nrc)};
      }
      return {'success': false, 'error': 'No response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Disconnect
  void disconnect() {
    if (_socket != null) {
      try {
        _socket!.close();
      } catch (e) {}
      _socket = null;
    }

    _zgwIp = null;
    _localIp = null;
    _huIp = null;
    _vin = null;
    _macAddress = null;
    _isConnected = false;
    _foundCars.clear();
    _log('🔌 Disconnected', level: 'warning');
    notifyListeners();
  }
}
