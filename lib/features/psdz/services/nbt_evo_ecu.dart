/// BMW NBT EVO ECU Complete Implementation
/// Full simulation of NBT EVO (Head Unit) with real BMW responses
/// Address: 0x63
///
/// Based on real BMW NBT EVO diagnostic data
/// Includes complete DID responses, coding data, and feature enablement

library nbt_evo_ecu;

import 'dart:typed_data';
import 'dart:io';

import 'virtual_ecu.dart';

/// NBT EVO Feature Flags
class NbtEvoFeatures {
  // Navigation
  static const int navigationPro = 0x0001;
  static const int liveTraffic = 0x0002;
  static const int onlineRouting = 0x0004;
  static const int mapUpdate = 0x0008;

  // Multimedia
  static const int appleCarPlay = 0x0010;
  static const int androidAuto = 0x0020;
  static const int wirelessCarPlay = 0x0040;
  static const int videoPlayback = 0x0080;

  // Connectivity
  static const int wifi = 0x0100;
  static const int bluetooth = 0x0200;
  static const int lte = 0x0400;
  static const int remoteServices = 0x0800;

  // Display
  static const int touchscreen = 0x1000;
  static const int gestureControl = 0x2000;
  static const int headUpDisplay = 0x4000;
  static const int instrumentCluster = 0x8000;

  // All features enabled
  static const int allFeatures = 0xFFFF;
}

/// NBT EVO Software Versions
class NbtEvoVersion {
  static const String softwareVersion = '21.07.530';
  static const String hardwareVersion = 'MGU_HW3';
  static const String bootloaderVersion = 'BTLD_001.002.003';
  static const String navigationVersion = 'NAV_EUR_2023';
  static const String mapVersion = 'WAY_2023Q3';
}

/// NBT EVO Virtual ECU - Complete Implementation
class NbtEvoEcu extends VirtualECU {
  // NBT-specific state
  int _enabledFeatures = NbtEvoFeatures.allFeatures;
  bool _navigationActive = true;
  bool _videoInMotionEnabled = false;
  bool _developerMenuEnabled = false;

  /// Variant name as seen in SVT (e.g. HU_NBT2, HU_NBT, HU_NBT_EVO, HU_MGU).
  ///
  /// Important: VirtualECU `name` is final, so the variant must be chosen at
  /// construction time.
  final String variantName;

  // Coding data storage (loaded from CAFD)
  final Map<String, Uint8List> _codingBlocks = {};

  // PSDZ path for file loading
  String? psdzDataPath;

  NbtEvoEcu({
    super.diagAddress = 0x63,
    this.variantName = 'HU_NBT2',
    super.name = 'HU_NBT2',
    this.psdzDataPath,
  }) {
    _initNbtEvoDids();
  }

  /// Helper for factories/routers that want to normalize various SVT names.
  static String normalizeVariantName(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'HU_NBT2';
    // Common HU variants
    final u = v.toUpperCase();
    if (u.contains('MGU')) return 'HU_MGU';
    if (u.contains('NBT2')) return 'HU_NBT2';
    if (u.contains('NBT_EVO') || u.contains('NBTEVO')) return 'HU_NBT_EVO';
    if (u.contains('NBT')) return 'HU_NBT2';
    // Fallback: keep as-is (but trimmed)
    return v;
  }

  /// Initialize all NBT EVO specific DIDs
  void _initNbtEvoDids() {
    // Ensure a sane identity for NBT2/NBT_EVO/MGU and avoid global DID 0xF100
    // behavior from VirtualECU (VIN+I-Step) unless explicitly desired.
    final effectiveVariant = normalizeVariantName(variantName);

    // DID 0xF100: many BMW captures use this as ECU address on HU, while our
    // VirtualECU default special-cases 0xF100 as VIN+I-Step. Override via mapping.
    mapping.registerDid(0xF100, (ecu, did, req) {
      // Return ECU address (2 bytes) - matches what many tools expect on HU.
      return Uint8List.fromList([0x00, diagAddress & 0xFF]);
    });

    // === Standard Identification DIDs ===

    // F186 - Active Diagnostic Session
    setDID(0xF186, Uint8List.fromList([0x01]));

    // F187 - ECU Part Number
    setDID(
      0xF187,
      Uint8List.fromList('65829414853-01'.padRight(20, '\x00').codeUnits),
    );

    // F188 - ECU Software Number
    setDID(
      0xF188,
      Uint8List.fromList(
        effectiveVariant.padRight(24, '\x00').codeUnits.take(24).toList(),
      ),
    );

    // F189 - ECU Software Version
    setDID(
      0xF189,
      Uint8List.fromList(
        NbtEvoVersion.softwareVersion.padRight(16, '\x00').codeUnits,
      ),
    );

    // F18A - System Supplier
    setDID(0xF18A, Uint8List.fromList('HARMAN'.padRight(16, '\x00').codeUnits));

    // F18B - Manufacturing Date
    setDID(0xF18B, Uint8List.fromList([0x20, 0x23, 0x06, 0x15])); // 2023-06-15

    // F18C - Serial Number
    setDID(0xF18C, Uint8List.fromList('HU00000012345678'.codeUnits));

    // F190 - VIN
    setDID(0xF190, Uint8List.fromList(vin.padRight(17, '\x00').codeUnits));

    // F191 - Hardware Number
    setDID(
      0xF191,
      Uint8List.fromList('65829414853'.padRight(16, '\x00').codeUnits),
    );

    // F192 - Hardware Version
    setDID(0xF192, Uint8List.fromList('03'.codeUnits));

    // F193 - System Supplier HW Number
    setDID(
      0xF193,
      Uint8List.fromList('HARMAN-MGU-03'.padRight(16, '\x00').codeUnits),
    );

    // F194 - System Supplier HW Version
    setDID(0xF194, Uint8List.fromList('03'.padRight(8, '\x00').codeUnits));

    // F195 - System Supplier SW Number
    setDID(
      0xF195,
      Uint8List.fromList('MGU_SW_21.07'.padRight(16, '\x00').codeUnits),
    );

    // F197 - System Name
    setDID(
      0xF197,
      Uint8List.fromList(
        effectiveVariant.padRight(16, '\x00').codeUnits.take(16).toList(),
      ),
    );

    // F199 - Programming Date
    setDID(0xF199, Uint8List.fromList([0x20, 0x24, 0x01, 0x28])); // 2024-01-28

    // === NBT EVO Specific DIDs ===

    // 1000 - ECU Identification Data
    setDID(0x1000, _buildEcuIdentification());

    // 1001 - ECU Configuration
    setDID(0x1001, _buildEcuConfiguration());

    // 1010 - Address Info
    setDID(0x1010, Uint8List.fromList([0x00, 0x63]));

    // 1011 - Supplier Info
    setDID(
      0x1011,
      Uint8List.fromList('HARMAN-BMW'.padRight(16, '\x00').codeUnits),
    );

    // 1735 - NBT Status
    setDID(0x1735, Uint8List.fromList([0x00])); // OK

    // 1736 - NBT Mode
    setDID(0x1736, Uint8List.fromList([0x01, 0x00])); // Normal mode

    // 1737 - Feature Status
    setDID(0x1737, _buildFeatureStatus());

    // 1738 - Configuration Data
    setDID(0x1738, Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0xFF, 0xFF]));

    // 1739 - Navigation Status
    setDID(
      0x1739,
      Uint8List.fromList([
        _navigationActive ? 0x01 : 0x00,
        0x00, // Route status
        0x00, 0x00, // Distance
      ]),
    );

    // 173A - Media Status
    setDID(0x173A, Uint8List.fromList([0x00, 0x00, 0x00, 0x00]));

    // 173B - Bluetooth Status
    setDID(0x173B, Uint8List.fromList([0x01, 0x00])); // BT enabled

    // 173C - WiFi Status
    setDID(0x173C, Uint8List.fromList([0x01, 0x00])); // WiFi enabled

    // 173D - LTE Status
    setDID(
      0x173D,
      Uint8List.fromList([0x01, 0x00, 0x00, 0x00]),
    ); // LTE connected

    // 2000 - Activation Status
    setDID(0x2000, Uint8List.fromList([0x01])); // Activated

    // 2001 - Feature Enablement
    setDID(
      0x2001,
      Uint8List.fromList([
        (_enabledFeatures >> 24) & 0xFF,
        (_enabledFeatures >> 16) & 0xFF,
        (_enabledFeatures >> 8) & 0xFF,
        _enabledFeatures & 0xFF,
      ]),
    );

    // 2002 - CarPlay Status
    setDID(
      0x2002,
      Uint8List.fromList([0x01, 0x01]),
    ); // CarPlay enabled, wired + wireless

    // 2003 - Android Auto Status
    setDID(0x2003, Uint8List.fromList([0x01, 0x00])); // AA enabled, wired only

    // 2004 - Video Playback Status
    setDID(0x2004, Uint8List.fromList([_videoInMotionEnabled ? 0x01 : 0x00]));

    // 2005 - Developer Menu Status
    setDID(0x2005, Uint8List.fromList([_developerMenuEnabled ? 0x01 : 0x00]));

    // 3000 - Coding Status
    setDID(0x3000, Uint8List.fromList([0x00])); // Coded

    // 3001 - CAFD Version
    setDID(0x3001, Uint8List.fromList([0x01, 0x00, 0x00]));

    // 3F06 - I-Step Current
    final iStepBytes = iStep.padRight(24, '\x00').codeUnits.take(24).toList();
    setDID(0x3F06, Uint8List.fromList(iStepBytes));

    // 6000 - Diagnostic Status
    setDID(0x6000, Uint8List.fromList([0x00, 0x00])); // No errors

    // 6001 - System Health
    setDID(0x6001, Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF])); // All OK

    // 6310 - Hardware Info
    setDID(0x6310, Uint8List.fromList([0x01, 0x00, 0x03, 0x00])); // HW Rev 3

    // === SVK / Software Parts DIDs ===

    // F101 - SVK Backup
    setDID(0xF101, _buildNbtEvoSvk());

    // F150 - SVK Current
    setDID(0xF150, _buildNbtEvoSvk());

    // === Coding DIDs (0x1000 - 0x1FFF range) ===
    _initCodingDids();

    // === NBT EVO Complete DID Map ===
    _initCompleteDids();
  }

  /// Initialize coding-related DIDs
  void _initCodingDids() {
    // CAFD Coding data slots
    for (int i = 0x1100; i <= 0x11FF; i++) {
      setDID(i, Uint8List.fromList(List.filled(32, 0xFF)));
    }

    // 1200 - Main Coding Block
    setDID(0x1200, _buildMainCodingBlock());

    // 1201 - Navigation Coding
    setDID(0x1201, _buildNavigationCoding());

    // 1202 - Media Coding
    setDID(0x1202, _buildMediaCoding());

    // 1203 - Connectivity Coding
    setDID(0x1203, _buildConnectivityCoding());

    // 1204 - Display Coding
    setDID(0x1204, _buildDisplayCoding());

    // 1205 - Vehicle Integration Coding
    setDID(0x1205, _buildVehicleIntegrationCoding());
  }

  /// Initialize complete DID responses - full list
  void _initCompleteDids() {
    // === F1XX Range - Standard DIDs ===
    setDID(0xF100, Uint8List.fromList([0x00, 0x63])); // ECU Address
    setDID(0xF101, _buildNbtEvoSvk());
    setDID(
      0xF102,
      Uint8List.fromList(
        'SWFL_00001BBE_021_007_530'.padRight(32, '\x00').codeUnits,
      ),
    );
    setDID(
      0xF103,
      Uint8List.fromList(
        'BTLD_00001BBF_001_002_003'.padRight(32, '\x00').codeUnits,
      ),
    );
    setDID(0xF110, Uint8List.fromList([0x00])); // Coding status
    setDID(0xF111, Uint8List.fromList([0x01])); // HW/SW compatibility OK
    setDID(
      0xF120,
      Uint8List.fromList(
        'CAFD_00001C28_019_021_015'.padRight(32, '\x00').codeUnits,
      ),
    ); // SGBM-ID
    setDID(
      0xF121,
      Uint8List.fromList(
        NbtEvoVersion.bootloaderVersion.padRight(24, '\x00').codeUnits,
      ),
    );
    setDID(
      0xF122,
      Uint8List.fromList('DIAG_V1.0'.padRight(16, '\x00').codeUnits),
    );

    // F1A0-F1AF - Version DIDs
    setDID(
      0xF1A0,
      Uint8List.fromList(
        NbtEvoVersion.hardwareVersion.padRight(16, '\x00').codeUnits,
      ),
    );
    setDID(
      0xF1A1,
      Uint8List.fromList(
        NbtEvoVersion.softwareVersion.padRight(16, '\x00').codeUnits,
      ),
    );
    setDID(
      0xF1A2,
      Uint8List.fromList('CAL_V1.0'.padRight(16, '\x00').codeUnits),
    );
    setDID(
      0xF1A3,
      Uint8List.fromList(
        NbtEvoVersion.navigationVersion.padRight(16, '\x00').codeUnits,
      ),
    );
    setDID(
      0xF1A4,
      Uint8List.fromList(
        NbtEvoVersion.mapVersion.padRight(16, '\x00').codeUnits,
      ),
    );

    // F1B0-F1BF - Calibration DIDs
    setDID(
      0xF1B0,
      Uint8List.fromList('CAL_HU_001'.padRight(16, '\x00').codeUnits),
    );
    setDID(
      0xF1B1,
      Uint8List.fromList('CAL_NAV_001'.padRight(16, '\x00').codeUnits),
    );
    setDID(
      0xF1B2,
      Uint8List.fromList('CAL_MEDIA_001'.padRight(16, '\x00').codeUnits),
    );

    // F1D0-F1DF - Boot/App DIDs
    setDID(
      0xF1D0,
      Uint8List.fromList(
        NbtEvoVersion.bootloaderVersion.padRight(16, '\x00').codeUnits,
      ),
    );
    setDID(
      0xF1D1,
      Uint8List.fromList('APP_HU_MGU'.padRight(16, '\x00').codeUnits),
    );
    setDID(0xF1DF, Uint8List.fromList([0x01, 0x00, 0x00, 0x00]));

    // F19E - Extended VIN
    setDID(0xF19E, Uint8List.fromList(vin.padRight(17, '\x00').codeUnits));

    // === 2XXX Range - Feature/Status DIDs ===
    setDID(
      0x2100,
      Uint8List.fromList([0x01, 0x00, 0x00, 0x00]),
    ); // Navigation enabled
    setDID(0x2101, Uint8List.fromList([0x01])); // Maps available
    setDID(
      0x2102,
      Uint8List.fromList([0x00, 0x00, 0x00, 0x00]),
    ); // GPS coordinates
    setDID(0x2103, Uint8List.fromList([0x00])); // Route active

    setDID(0x2200, Uint8List.fromList([0x01, 0x00])); // Media source
    setDID(0x2201, Uint8List.fromList([0x00])); // Radio active
    setDID(0x2202, Uint8List.fromList([0x00])); // USB connected
    setDID(0x2203, Uint8List.fromList([0x00])); // Streaming active

    setDID(0x2300, Uint8List.fromList([0x01])); // Phone connected
    setDID(0x2301, Uint8List.fromList([0x00])); // Call active
    setDID(0x2302, Uint8List.fromList([0x00, 0x00])); // Phonebook sync

    // 2500-25FF - I-Level DIDs
    final iLevelBytes = iStep.padRight(24, '\x00').codeUnits.take(24).toList();
    setDID(0x2500, Uint8List.fromList(iLevelBytes));
    setDID(0x2501, Uint8List.fromList(iLevelBytes)); // Ship
    setDID(0x2502, Uint8List.fromList(iLevelBytes)); // Target
    setDID(0x2503, Uint8List.fromList(iLevelBytes)); // Current
    setDID(0x2504, Uint8List.fromList(iLevelBytes)); // Backup
    setDID(0x2505, Uint8List.fromList(iLevelBytes)); // Last

    // === 3XXX Range - Coding/Configuration ===
    setDID(0x3100, Uint8List.fromList([0x00])); // Coding valid
    setDID(
      0x3101,
      Uint8List.fromList([0x01, 0x00, 0x00, 0x00]),
    ); // Coding version

    // 3FD0 - FA Data
    // Will be updated from loadFA

    // 3FE0 - FP Data
    setDID(0x3FE0, Uint8List.fromList(List.filled(16, 0xFF)));

    // === 4XXX Range - Diagnostics ===
    setDID(0x4000, Uint8List.fromList([0x00])); // DTC count
    setDID(0x4001, Uint8List.fromList([0x00, 0x00, 0x00, 0x00])); // Last DTC

    // === 5XXX Range - Network Status ===
    setDID(0x5000, Uint8List.fromList([0x01])); // Network OK
    setDID(0x5001, Uint8List.fromList([0x01])); // MOST OK
    setDID(0x5002, Uint8List.fromList([0x01])); // Ethernet OK

    // === 6XXX Range - System Health ===
    setDID(0x6100, Uint8List.fromList([0x00, 0x00])); // Temperature
    setDID(0x6101, Uint8List.fromList([0x0C, 0x00])); // Voltage (12V)
    setDID(0x6102, Uint8List.fromList([0x00])); // Memory usage
    setDID(0x6103, Uint8List.fromList([0x00])); // CPU usage

    // === D1XX Range - Vehicle Data ===
    setDID(
      0xD100,
      Uint8List.fromList(List.filled(64, 0x00)),
    ); // FA - will be updated
    setDID(0xD101, Uint8List.fromList(List.filled(16, 0xFF))); // FP
    setDID(0xD102, Uint8List.fromList([0x00, 0x00])); // SVT Status
  }

  /// Build ECU identification block
  Uint8List _buildEcuIdentification() {
    final data = <int>[];

    // ECU Type
    data.addAll(
      normalizeVariantName(variantName).padRight(16, '\x00').codeUnits,
    );

    // Hardware version
    data.addAll([0x03, 0x00]); // HW v3

    // Software version
    data.addAll([0x15, 0x07, 0x02, 0x12]); // v21.07.530

    // Manufacturer
    data.addAll('HARMAN'.padRight(8, '\x00').codeUnits);

    // Production date
    data.addAll([0x20, 0x23, 0x06, 0x15]);

    return Uint8List.fromList(data);
  }

  /// Build ECU configuration block
  Uint8List _buildEcuConfiguration() {
    return Uint8List.fromList([
      0x01, // Version
      0x00, 0x63, // ECU Address
      0xFF, 0xFF, // Features enabled (all)
      0x01, // Navigation active
      0x01, // CarPlay enabled
      0x01, // Android Auto enabled
      0x01, // Bluetooth enabled
      0x01, // WiFi enabled
      0x01, // LTE enabled
      0x01, // Touchscreen enabled
      0x00, // Video in motion disabled
      0x00, // Dev menu disabled
      0x00, 0x00, // Reserved
    ]);
  }

  /// Build feature status
  Uint8List _buildFeatureStatus() {
    return Uint8List.fromList([
      (_enabledFeatures >> 8) & 0xFF,
      _enabledFeatures & 0xFF,
    ]);
  }

  /// Build NBT EVO SVK (Software Version Key)
  Uint8List _buildNbtEvoSvk() {
    final parts = <int>[];

    // SVK Header
    parts.addAll([0x01, 0x00, 0x04]); // Version, 4 parts

    // Part 1: SWFL - Main Software
    parts.addAll('SWFL'.codeUnits);
    parts.addAll([0x00, 0x00, 0x1B, 0xBE]); // ID: 0x1BBE
    parts.addAll([0x00, 0x15, 0x07]); // Version: 021.007.530
    parts.add(0x12);

    // Part 2: BTLD - Bootloader
    parts.addAll('BTLD'.codeUnits);
    parts.addAll([0x00, 0x00, 0x1B, 0xBF]); // ID: 0x1BBF
    parts.addAll([0x00, 0x01, 0x02]); // Version: 001.002.003
    parts.add(0x03);

    // Part 3: CAFD - Coding Data
    parts.addAll('CAFD'.codeUnits);
    parts.addAll([0x00, 0x00, 0x1C, 0x28]); // ID: 0x1C28
    parts.addAll([0x00, 0x13, 0x15]); // Version: 019.021.015
    parts.add(0x0F);

    // Part 4: FLSH - Flash Data
    parts.addAll('FLSH'.codeUnits);
    parts.addAll([0x00, 0x00, 0x1C, 0x29]); // ID: 0x1C29
    parts.addAll([0x00, 0x01, 0x00]); // Version: 001.000.000
    parts.add(0x00);

    return Uint8List.fromList(parts);
  }

  /// Build main coding block
  Uint8List _buildMainCodingBlock() {
    // Typical NBT EVO coding structure
    return Uint8List.fromList([
      0x01, // Block version
      0x00, 0x63, // ECU address
      0xFF, 0xFF, 0xFF, 0xFF, // Features bitmap
      0x01, // Country code (EU)
      0x01, // Language (German)
      0x01, // Units (Metric)
      0x00, 0x00, 0x00, 0x00, // Reserved
      0x00, 0x00, 0x00, 0x00, // Reserved
    ]);
  }

  /// Build navigation coding
  Uint8List _buildNavigationCoding() {
    return Uint8List.fromList([
      0x01, // NAV enabled
      0x01, // Pro navigation
      0x01, // Live traffic
      0x01, // Online routing
      0x01, // Map update
      0x01, // Speed camera warnings
      0x01, // Lane guidance
      0x01, // 3D buildings
    ]);
  }

  /// Build media coding
  Uint8List _buildMediaCoding() {
    return Uint8List.fromList([
      0x01, // Radio enabled
      0x01, // DAB enabled
      0x01, // USB enabled
      0x01, // Bluetooth audio
      0x01, // Streaming
      0x00, // Video in motion
      0x01, // DVD (if equipped)
      0x01, // Album art
    ]);
  }

  /// Build connectivity coding
  Uint8List _buildConnectivityCoding() {
    return Uint8List.fromList([
      0x01, // Bluetooth
      0x01, // WiFi
      0x01, // LTE
      0x01, // Apple CarPlay
      0x01, // Android Auto
      0x01, // Wireless CarPlay
      0x01, // Remote Services
      0x01, // OTA Updates
    ]);
  }

  /// Build display coding
  Uint8List _buildDisplayCoding() {
    return Uint8List.fromList([
      0x01, // Touch enabled
      0x01, // iDrive controller
      0x01, // Gesture control
      0x01, // HUD enabled
      0x01, // Instrument cluster link
      0x02, // Theme (Dark)
      0x00, 0x00, // Reserved
    ]);
  }

  /// Build vehicle integration coding
  Uint8List _buildVehicleIntegrationCoding() {
    return Uint8List.fromList([
      0x01, // CAN integration
      0x01, // Most integration
      0x01, // Ethernet
      0x01, // Camera input
      0x01, // Parking sensors
      0x01, // 360 view
      0x01, // Active cruise display
      0x01, // Lane assist display
    ]);
  }

  /// Enable/disable feature
  void setFeature(int feature, bool enabled) {
    if (enabled) {
      _enabledFeatures |= feature;
    } else {
      _enabledFeatures &= ~feature;
    }

    // Update DIDs
    setDID(
      0x2001,
      Uint8List.fromList([
        (_enabledFeatures >> 24) & 0xFF,
        (_enabledFeatures >> 16) & 0xFF,
        (_enabledFeatures >> 8) & 0xFF,
        _enabledFeatures & 0xFF,
      ]),
    );
    setDID(0x1737, _buildFeatureStatus());
  }

  /// Enable video in motion
  void setVideoInMotion(bool enabled) {
    _videoInMotionEnabled = enabled;
    setDID(0x2004, Uint8List.fromList([enabled ? 0x01 : 0x00]));
  }

  /// Enable developer menu
  void setDeveloperMenu(bool enabled) {
    _developerMenuEnabled = enabled;
    setDID(0x2005, Uint8List.fromList([enabled ? 0x01 : 0x00]));
  }

  /// Load CAFD coding from PSDZ file
  Future<void> loadCafdFromFile(String cafdPath) async {
    try {
      final file = File(cafdPath);
      if (!await file.exists()) return;

      final content = await file.readAsBytes();

      // Parse CAFD structure
      if (content.length >= 16) {
        // Store raw CAFD data
        _codingBlocks['main'] = Uint8List.fromList(content);

        // Update coding DIDs
        if (content.length >= 64) {
          setDID(0x1200, content.sublist(0, 64));
        }
        if (content.length >= 128) {
          setDID(0x1201, content.sublist(64, 128));
        }
        if (content.length >= 192) {
          setDID(0x1202, content.sublist(128, 192));
        }
        if (content.length >= 256) {
          setDID(0x1203, content.sublist(192, 256));
        }

        // Update SGBM-ID from filename if possible
        final filename = cafdPath.split('/').last.split('\\').last;
        if (filename.startsWith('CAFD')) {
          setDID(
            0xF120,
            Uint8List.fromList(
              filename
                  .replaceAll('.caf', '')
                  .padRight(32, '\x00')
                  .codeUnits
                  .take(32)
                  .toList(),
            ),
          );
        }
      }
    } catch (e) {
      // Ignore load errors
    }
  }

  /// Load multiple CAFD files from PSDZ path
  Future<void> loadFromPsdz(String psdzPath) async {
    psdzDataPath = psdzPath;

    // Look for HU/NBT CAFD files
    final sweDir = Directory('$psdzPath/swe');
    if (!await sweDir.exists()) return;

    await for (var entity in sweDir.list(recursive: true)) {
      if (entity is File) {
        final name = entity.path.split('/').last.split('\\').last.toLowerCase();
        if (name.startsWith('cafd') &&
            (name.contains('hu_') ||
                name.contains('nbt') ||
                name.contains('mgu'))) {
          await loadCafdFromFile(entity.path);
          break; // Load first matching file
        }
      }
    }
  }

  /// Get all supported DIDs
  List<int> get supportedDids {
    final dids = <int>[];

    // Standard F1XX range
    dids.addAll([
      0xF100,
      0xF101,
      0xF102,
      0xF103,
      0xF110,
      0xF111,
      0xF120,
      0xF121,
      0xF122,
      0xF150,
      0xF186,
      0xF187,
      0xF188,
      0xF189,
      0xF18A,
      0xF18B,
      0xF18C,
      0xF190,
      0xF191,
      0xF192,
      0xF193,
      0xF194,
      0xF195,
      0xF197,
      0xF199,
      0xF19E,
      0xF1A0,
      0xF1A1,
      0xF1A2,
      0xF1A3,
      0xF1A4,
      0xF1B0,
      0xF1B1,
      0xF1B2,
      0xF1D0,
      0xF1D1,
      0xF1DF,
    ]);

    // NBT specific
    dids.addAll([
      0x1000,
      0x1001,
      0x1010,
      0x1011,
      0x1200,
      0x1201,
      0x1202,
      0x1203,
      0x1204,
      0x1205,
      0x1735,
      0x1736,
      0x1737,
      0x1738,
      0x1739,
      0x173A,
      0x173B,
      0x173C,
      0x173D,
      0x2000,
      0x2001,
      0x2002,
      0x2003,
      0x2004,
      0x2005,
      0x2100,
      0x2101,
      0x2102,
      0x2103,
      0x2200,
      0x2201,
      0x2202,
      0x2203,
      0x2300,
      0x2301,
      0x2302,
      0x2500,
      0x2501,
      0x2502,
      0x2503,
      0x2504,
      0x2505,
      0x3000,
      0x3001,
      0x3100,
      0x3101,
      0x3F06,
      0x3FD0,
      0x3FE0,
      0x4000,
      0x4001,
      0x5000,
      0x5001,
      0x5002,
      0x6000,
      0x6001,
      0x6100,
      0x6101,
      0x6102,
      0x6103,
      0x6310,
      0xD100,
      0xD101,
      0xD102,
    ]);

    return dids;
  }
}

/// Factory for creating pre-configured NBT EVO ECUs
class NbtEvoFactory {
  /// Create NBT EVO with all features enabled
  static NbtEvoEcu createFullFeatured({String? psdzPath}) {
    final ecu = NbtEvoEcu(psdzDataPath: psdzPath);
    ecu.setVideoInMotion(true);
    ecu.setDeveloperMenu(true);
    return ecu;
  }

  /// Create NBT EVO with standard features
  static NbtEvoEcu createStandard({String? psdzPath}) {
    return NbtEvoEcu(psdzDataPath: psdzPath);
  }

  /// Create NBT EVO with navigation only (no CarPlay/AA)
  static NbtEvoEcu createNavigationOnly({String? psdzPath}) {
    final ecu = NbtEvoEcu(psdzDataPath: psdzPath);
    ecu.setFeature(NbtEvoFeatures.appleCarPlay, false);
    ecu.setFeature(NbtEvoFeatures.androidAuto, false);
    return ecu;
  }
}
