/// Simulation Export Service
/// Exports simulation state including SVT, FA, ECU info, and NCD backups.
///
/// Features:
/// - Export SVT and FA to XML
/// - Export ECU details to JSON
/// - Dump NCD coding data
/// - Create comprehensive backup package
///
/// Developer: M A coding
/// Website: https://bmw-az.info/
/// Signature: AQ///bimmer

library simulation_export_service;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

import '../models/tal_file.dart';
import '../models/ecu.dart';
import '../models/istep.dart';
import 'virtual_ecu.dart';

class SimulationExportService {
  /// Export full simulation state to a directory
  Future<String> exportSimulation({
    required String exportPath,
    required List<VirtualECU> ecus,
    required FAData? fa,
    required SVTData? svt,
    String? vin,
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final baseDir = Directory('$exportPath/SimulationBackup_$timestamp');
    await baseDir.create(recursive: true);

    // 1. Export FA
    if (fa != null) {
      await _exportFA(baseDir, fa);
    }

    // 2. Export SVT
    if (svt != null) {
      await _exportSVT(baseDir, svt);
    }

    // 3. Export ECU Info & NCDs
    await _exportEcus(baseDir, ecus);

    return baseDir.path;
  }

  Future<void> _exportFA(Directory dir, FAData fa) async {
    final file = File('${dir.path}/fa.xml');
    // Simple XML reconstruction for FA
    final xml =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<FA>
  <VIN>${fa.vin}</VIN>
  <Type>${fa.typeKey}</Type>
  <Series>${fa.series}</Series>
  <Date>${fa.productionDate?.toIso8601String() ?? ''}</Date>
  <SAList>
    ${fa.saCodes.map((c) => '<Element>$c</Element>').join('\n    ')}
  </SAList>
  <HOList>
    ${fa.hoCodes.map((c) => '<Element>$c</Element>').join('\n    ')}
  </HOList>
  <EList>
    ${fa.eCodes.map((c) => '<Element>$c</Element>').join('\n    ')}
  </EList>
</FA>
''';
    await file.writeAsString(xml);
  }

  Future<void> _exportSVT(Directory dir, SVTData svt) async {
    final file = File('${dir.path}/svt_soll.xml');
    // We would ideally use a proper XML builder here, but for now a simplified version
    // or just dumping the raw bytes if we had the original file would be better.
    // Since we parsed it into objects, we reconstruct a basic structure.

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<SVT>');
    for (final ecu in svt.ecus) {
      buffer.writeln('  <ECU>');
      buffer.writeln('    <Name>${ecu.name}</Name>');
      buffer.writeln('    <BaseVariant>${ecu.baseVariant}</BaseVariant>');
      buffer.writeln(
        '    <DiagnosticAddress>0x${ecu.address.toRadixString(16).toUpperCase()}</DiagnosticAddress>',
      );
      buffer.writeln('  </ECU>');
    }
    buffer.writeln('</SVT>');

    await file.writeAsString(buffer.toString());
  }

  Future<void> _exportEcus(Directory dir, List<VirtualECU> ecus) async {
    final ecusDir = Directory('${dir.path}/ecus');
    await ecusDir.create();

    final ncdDir = Directory('${dir.path}/ncd');
    await ncdDir.create();

    final ecuList = [];

    for (final ecu in ecus) {
      // ECU Info
      ecuList.add({
        'name': ecu.name,
        'address': '0x${ecu.diagAddress.toRadixString(16).toUpperCase()}',
        'vin': ecu.vin,
        'iStep': ecu.iStep,
        'variant': ecu.variantCoding,
      });

      // Dump NCD (Coding Data)
      // In a real scenario, we would construct a valid NCD binary from the ECU's memory.
      // Here we simulate it by dumping the raw coding data if available.
      if (ecu.codingData.isNotEmpty) {
        final ncdFile = File(
          '${ncdDir.path}/${ecu.name}_${ecu.diagAddress.toRadixString(16)}.ncd',
        );
        // Combine all coding blocks into one file (simplified)
        final bytes = <int>[];
        // Header (fake)
        bytes.addAll([0x00, 0x00, 0x00, 0x00]);

        ecu.codingData.forEach((key, value) {
          // Block ID (2 bytes) + Length (2 bytes) + Data
          // This is a simplified structure, real NCD is more complex.
          // But for "backup" purposes to be read back by OUR tool, this is fine.
          // If it needs to be read by E-Sys, we need the exact NCD format.
          // For now, we dump raw data.
          bytes.addAll(value);
        });

        await ncdFile.writeAsBytes(bytes);
      }
    }

    final jsonFile = File('${ecusDir.path}/ecu_list.json');
    await jsonFile.writeAsString(jsonEncode(ecuList));
  }
}
