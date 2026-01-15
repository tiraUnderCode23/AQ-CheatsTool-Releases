/// BMW ATM (Advanced Telecommunication Module) ECU Implementation
/// Address: 0x61
///
/// Simulates the Telematics module to prevent "ATM not present" errors in ISTA.
/// Implements specific DIDs for connection status, IMEI, and SIM data.

library atm_ecu;

import 'dart:typed_data';
import 'virtual_ecu.dart';

class AtmEcu extends VirtualECU {
  AtmEcu({super.diagAddress = 0x61, super.name = 'ATM'}) {
    _initAtmDids();
  }

  void _initAtmDids() {
    // === Standard Identification ===
    setDID(0xF186, Uint8List.fromList([0x01])); // Active Session
    setDID(
      0xF187,
      Uint8List.fromList('8412345-01'.padRight(12).codeUnits),
    ); // Part Number
    setDID(
      0xF190,
      Uint8List.fromList(vin.padRight(17, '\x00').codeUnits),
    ); // VIN
    setDID(0xF18C, Uint8List.fromList('ATM0000001'.codeUnits)); // Serial

    // === ATM Specific DIDs (from logs) ===

    // D108 - Telematics Status / Network Status
    // ISTA expects valid data here.
    // Format: Status(1) + SignalStrength(1) + Roaming(1) + Service(1) + ...
    setDID(
      0xD108,
      Uint8List.fromList([
        0x01, // Connected
        0x05, // Signal Strength (5 bars)
        0x00, // No Roaming
        0x01, // LTE Service
        0x00, 0x00, 0x00, 0x00, // Reserved
      ]),
    );

    // D06B - IMEI / Device ID
    // Format: ASCII IMEI (15 chars) + padding
    setDID(
      0xD06B,
      Uint8List.fromList('351234567890123'.padRight(16, '\x00').codeUnits),
    );

    // D100 - SIM Status
    setDID(0xD100, Uint8List.fromList([0x01])); // SIM Present

    // D101 - ICCID
    setDID(
      0xD101,
      Uint8List.fromList('8901234567890123456'.padRight(20, '\x00').codeUnits),
    );

    // === Common BMW DIDs ===
    setDID(0x1735, Uint8List.fromList([0x00])); // Status OK
  }

  @override
  void loadFA(FAData fa) {
    super.loadFA(fa);
    // Update VIN in specific DIDs if needed
    setDID(0xF190, Uint8List.fromList(vin.padRight(17, '\x00').codeUnits));
  }
}
