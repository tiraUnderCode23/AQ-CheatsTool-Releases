// BMW Virtual ECU - Full Implementation
// Based on original Python VirtualECU with 100% real BMW protocol support

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import 'uds_mapping_registry.dart';

/// Process class for SVK parts
enum ProcessClass {
  cafd(0x0001),
  swfl(0x0002),
  btld(0x0003),
  flsh(0x0004);

  final int value;
  const ProcessClass(this.value);
}

/// ECU Part information for SVK building
class ECUPart {
  final ProcessClass processClass;
  final int id;
  final int version;
  final String? sgbmId;
  final Uint8List? data;

  ECUPart({
    required this.processClass,
    required this.id,
    required this.version,
    this.sgbmId,
    this.data,
  });

  /// Parse SGBM ID to extract process class, ID and version
  static ECUPart? fromSgbmId(String sgbmId) {
    // Format: SWFL_00012345_001_002_003 or CAFD_00012345_01_02_03
    final parts = sgbmId.toUpperCase().split('_');
    if (parts.length < 5) return null;

    ProcessClass? pc;
    switch (parts[0]) {
      case 'CAFD':
        pc = ProcessClass.cafd;
        break;
      case 'SWFL':
        pc = ProcessClass.swfl;
        break;
      case 'BTLD':
        pc = ProcessClass.btld;
        break;
      case 'FLSH':
        pc = ProcessClass.flsh;
        break;
      default:
        return null;
    }

    int _parseIntFlexible(String s) {
      final t = s.trim();
      if (t.isEmpty) return 0;
      if (t.startsWith('0X')) {
        return int.tryParse(t.substring(2), radix: 16) ?? 0;
      }
      // If it contains hex letters, treat as hex.
      final hasHexLetters = RegExp(r'[A-F]').hasMatch(t);
      if (hasHexLetters) {
        return int.tryParse(t, radix: 16) ?? 0;
      }
      // Try decimal first, then hex.
      return int.tryParse(t) ?? int.tryParse(t, radix: 16) ?? 0;
    }

    try {
      final id = _parseIntFlexible(parts[1]);
      final v1 = _parseIntFlexible(parts[2]);
      final v2 = _parseIntFlexible(parts[3]);
      final v3 = _parseIntFlexible(parts[4]);
      final version = (v1 << 16) | (v2 << 8) | v3;

      return ECUPart(
        processClass: pc,
        id: id,
        version: version,
        sgbmId: sgbmId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Build binary representation for SVK
  Uint8List toBytes() {
    final bytes = Uint8List(11);

    // Process Class (4 bytes) - ASCII
    String pcStr = '';
    switch (processClass) {
      case ProcessClass.cafd:
        pcStr = 'CAFD';
        break;
      case ProcessClass.swfl:
        pcStr = 'SWFL';
        break;
      case ProcessClass.btld:
        pcStr = 'BTLD';
        break;
      case ProcessClass.flsh:
        pcStr = 'FLSH';
        break;
    }

    final pcBytes = pcStr.padRight(4, '\x00').codeUnits;
    for (int i = 0; i < 4; i++) {
      bytes[i] = i < pcBytes.length ? pcBytes[i] : 0;
    }

    // ID (4 bytes)
    bytes[4] = (id >> 24) & 0xFF;
    bytes[5] = (id >> 16) & 0xFF;
    bytes[6] = (id >> 8) & 0xFF;
    bytes[7] = id & 0xFF;
    // Version (3 bytes)
    bytes[8] = (version >> 16) & 0xFF;
    bytes[9] = (version >> 8) & 0xFF;
    bytes[10] = version & 0xFF;

    return bytes;
  }
}

/// FA (Fahrzeugauftrag) Data structure
class FAData {
  String vin = 'WBA00000000000000';
  String typeKey = '0000';
  String series = 'G030';
  DateTime productionDate = DateTime.now();
  String paint = 'B39';
  String upholstery = 'LCSW';
  List<String> saCodes = [];
  List<String> eCodes = [];
  List<String> hoCodes = [];

  /// Parse FA from XML content
  void loadFromXml(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);

      // Handle namespaces (e.g., ns1:fa)
      final faElement =
          document.findAllElements('fa').firstOrNull ??
          document.findAllElements('ns1:fa').firstOrNull;

      if (faElement == null) return;

      // Parse Header for VIN
      final header =
          faElement.findAllElements('header').firstOrNull ??
          faElement.findAllElements('ns1:header').firstOrNull;

      if (header != null) {
        final vinLong = header.getAttribute('vinLong');
        if (vinLong != null) {
          vin = vinLong.padRight(17).substring(0, 17);
        }
      } else {
        // Fallback to old regex if header not found (legacy format)
        final vinMatch = RegExp(
          r'<VIN[^>]*>([^<]+)</VIN>',
        ).firstMatch(xmlContent);
        if (vinMatch != null) {
          vin = vinMatch.group(1)!.padRight(17).substring(0, 17);
        }
      }

      // Parse Standard FA
      final standardFA =
          faElement.findAllElements('standardFA').firstOrNull ??
          faElement.findAllElements('ns1:standardFA').firstOrNull;

      if (standardFA != null) {
        typeKey = standardFA.getAttribute('typeKey') ?? typeKey;
        series = standardFA.getAttribute('series') ?? series;

        // Parse SA Codes
        final saList = standardFA.findAllElements('saCode').isEmpty
            ? standardFA.findAllElements('ns1:saCode')
            : standardFA.findAllElements('saCode');

        saCodes = saList.map((node) => node.innerText).toList();

        // Parse E-Codes (E-Wort)
        final eList = standardFA.findAllElements('eCode').isEmpty
            ? standardFA.findAllElements('ns1:eCode')
            : standardFA.findAllElements('eCode');

        eCodes = eList.map((node) => node.innerText).toList();

        // Parse HO-Codes (HO-Wort)
        final hoList = standardFA.findAllElements('hoCode').isEmpty
            ? standardFA.findAllElements('ns1:hoCode')
            : standardFA.findAllElements('hoCode');

        hoCodes = hoList.map((node) => node.innerText).toList();
      } else {
        // Fallback regex parsing
        _loadFromXmlRegex(xmlContent);
      }

      debugPrint('FA loaded: VIN=$vin, Series=$series, SA=${saCodes.length}');
    } catch (e) {
      debugPrint('Error parsing FA XML: $e');
      // Fallback
      _loadFromXmlRegex(xmlContent);
    }
  }

  void _loadFromXmlRegex(String xmlContent) {
    // Parse VIN
    final vinMatch = RegExp(r'<VIN[^>]*>([^<]+)</VIN>').firstMatch(xmlContent);
    if (vinMatch != null) {
      vin = vinMatch.group(1)!.padRight(17).substring(0, 17);
    }

    // Parse Type Key
    final typeMatch = RegExp(
      r'<TYPE[^>]*>([^<]+)</TYPE>',
    ).firstMatch(xmlContent);
    if (typeMatch != null) {
      typeKey = typeMatch.group(1)!;
    }

    // Parse Series (Baureihe)
    final seriesMatch = RegExp(
      r'<BAUREIHE[^>]*>([^<]+)</BAUREIHE>',
    ).firstMatch(xmlContent);
    if (seriesMatch != null) {
      series = seriesMatch.group(1)!;
    }

    // Parse SA Codes
    final saMatches = RegExp(r'<SA[^>]*CODE="([^"]+)"').allMatches(xmlContent);
    if (saMatches.isNotEmpty) {
      saCodes = saMatches.map((m) => m.group(1)!).toList();
    }

    // Parse E-Wort
    final eMatches = RegExp(
      r'<E_WORT[^>]*WERT="([^"]+)"',
    ).allMatches(xmlContent);
    if (eMatches.isNotEmpty) {
      eCodes = eMatches.map((m) => m.group(1)!).toList();
    }

    // Parse HO-Wort
    final hoMatches = RegExp(
      r'<HO_WORT[^>]*WERT="([^"]+)"',
    ).allMatches(xmlContent);
    if (hoMatches.isNotEmpty) {
      hoCodes = hoMatches.map((m) => m.group(1)!).toList();
    }
  }

  /// Build binary FA for DID 0x1769 (VCM format for E-Sys)
  ///
  /// E-Sys VCM ReadFA expects a specific binary format:
  /// - NO length prefix (E-Sys adds it internally)
  /// - Starts with FA_KENNUNG (version/marker)
  /// - Followed by structured vehicle data
  ///
  /// Based on BMW E-Sys MCD3_ReadFAFromVCM job expectations
  Uint8List toBinaryVCM() {
    final buffer = <int>[];

    // === FA HEADER ===
    // FA_KENNUNG (1 byte) - FA Version/Type marker
    buffer.add(0x03); // Version 3 (F/G series)

    // ENTWICKLUNGS_BAUREIHE (4 bytes) - Development Series Code
    // E.g., "G030" for G30 series
    final devSeries = series.padRight(4, ' ');
    buffer.addAll(devSeries.codeUnits.take(4));

    // BR_NUMMER (2 bytes) - Type key as number
    final typeNum = int.tryParse(typeKey.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    buffer.add((typeNum >> 8) & 0xFF);
    buffer.add(typeNum & 0xFF);

    // PRODUKTIONSDATUM (3 bytes) - BCD Production Date: DD MM YY
    buffer.add(_toBCD(productionDate.day));
    buffer.add(_toBCD(productionDate.month));
    buffer.add(_toBCD(productionDate.year % 100));

    // ZEITKRITERIUM (1 byte) - Time criteria (typically 0x00)
    buffer.add(0x00);

    // LACKCODE (3 bytes) - Paint code as ASCII
    final paintCode = paint.padLeft(3, '0').substring(0, 3);
    buffer.addAll(paintCode.codeUnits.take(3));

    // POLSTERCODE (4 bytes) - Upholstery code as ASCII
    buffer.addAll(upholstery.padRight(4, ' ').codeUnits.take(4));

    // === SA-WORT SECTION ===
    // SA_ANZ (1 byte) - Count of SA codes
    buffer.add(saCodes.length & 0xFF);

    // SA entries (3 bytes each, ASCII)
    for (var sa in saCodes.take(255)) {
      // Extract numeric part: "S248A" -> "248" or "248A" -> "48A"
      String code = sa.replaceFirst(RegExp(r'^[Ss]'), '');
      code = code.padLeft(3, '0');
      if (code.length > 3) code = code.substring(code.length - 3);
      buffer.addAll(code.codeUnits.take(3));
    }

    // === E-WORT SECTION ===
    // E_ANZ (1 byte) - Count of E-Wort entries
    final eCount = eCodes.length.clamp(0, 255);
    buffer.add(eCount);

    // E-Wort entries (4 bytes each: 2 byte ID + 2 byte value)
    for (var e in eCodes.take(255)) {
      final parts = e.split('=');
      final idStr = parts.isNotEmpty
          ? parts[0].replaceAll(RegExp(r'[^\d]'), '')
          : '0';
      final id = int.tryParse(idStr) ?? 0;
      final value = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      buffer.add((id >> 8) & 0xFF);
      buffer.add(id & 0xFF);
      buffer.add((value >> 8) & 0xFF);
      buffer.add(value & 0xFF);
    }

    // === HO-WORT SECTION ===
    // HO_ANZ (1 byte) - Count of HO-Wort entries
    final hoCount = hoCodes.length.clamp(0, 255);
    buffer.add(hoCount);

    // HO-Wort entries (4 bytes each: 2 byte ID + 2 byte value)
    for (var ho in hoCodes.take(255)) {
      final parts = ho.split('=');
      final idStr = parts.isNotEmpty
          ? parts[0].replaceAll(RegExp(r'[^\d]'), '')
          : '0';
      final id = int.tryParse(idStr) ?? 0;
      final value = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      buffer.add((id >> 8) & 0xFF);
      buffer.add(id & 0xFF);
      buffer.add((value >> 8) & 0xFF);
      buffer.add(value & 0xFF);
    }

    // E-Sys expects raw FA data WITHOUT length prefix for DID 0x1769
    return Uint8List.fromList(buffer);
  }

  /// Convert number to BCD format (e.g., 25 -> 0x25)
  int _toBCD(int value) {
    final tens = (value ~/ 10) % 10;
    final ones = value % 10;
    return (tens << 4) | ones;
  }

  /// Build FA with length prefix (for DID 0x3FD0 and internal use)
  Uint8List toBinaryWithLength() {
    final rawFA = toBinaryVCM();
    final result = Uint8List(2 + rawFA.length);
    result[0] = (rawFA.length >> 8) & 0xFF;
    result[1] = rawFA.length & 0xFF;
    result.setRange(2, result.length, rawFA);
    return result;
  }

  /// Build FA for DID 0x3FD0 format (includes length prefix)
  Uint8List toBinary() {
    return toBinaryWithLength();
  }
}

/// SVT (Software Version Table) Data
class SVTData {
  String vin = '';
  String iStep = 'G030-23-07-550';
  List<SVTEcuData> ecus = [];

  int _parseAddressFlexible(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 0;
    final t = v.toUpperCase();
    if (t.startsWith('0X')) {
      return int.tryParse(t.substring(2), radix: 16) ?? 0;
    }
    // Common in BMW XML: hex without 0x
    final hasHexLetters = RegExp(r'[A-F]').hasMatch(t);
    if (hasHexLetters) {
      return int.tryParse(t, radix: 16) ?? 0;
    }
    // Try decimal then hex
    return int.tryParse(t) ?? int.tryParse(t, radix: 16) ?? 0;
  }

  String? _firstText(XmlDocument doc, List<String> tagNames) {
    for (final tag in tagNames) {
      final el = doc.findAllElements(tag).firstOrNull;
      if (el != null) {
        final txt = el.innerText.trim();
        if (txt.isNotEmpty) return txt;
      }
    }
    return null;
  }

  String? _firstAttr(XmlElement el, List<String> attrNames) {
    for (final a in attrNames) {
      final v = el.getAttribute(a);
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String? _childText(XmlElement el, List<String> tagNames) {
    for (final tag in tagNames) {
      final child = el.findAllElements(tag).firstOrNull;
      if (child != null) {
        final txt = child.innerText.trim();
        if (txt.isNotEmpty) return txt;
      }
    }
    return null;
  }

  void loadFromXml(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);

      // Parse VIN (try multiple locations)
      final vinFound = _firstText(document, [
        'VIN',
        'VIN17',
        'vin',
        'Vin',
      ])?.trim();
      if (vinFound != null && vinFound.isNotEmpty) {
        vin = vinFound;
      }

      // 2. From <svt> tag (Newer) - usually not directly in SVT but let's check

      // Parse I-Step
      final iStepFound = _firstText(document, [
        'I_STUFE_IST',
        'I_STUFE_WERK',
        'I_LEVEL',
        'iLevel',
        'iStep',
      ]);
      if (iStepFound != null && iStepFound.isNotEmpty) {
        iStep = iStepFound;
      }

      // Parse ECUs
      // Try multiple tag names (lowercase/new + uppercase/legacy)
      var ecuElements = document.findAllElements('ecu');
      if (ecuElements.isEmpty) ecuElements = document.findAllElements('ECU');
      if (ecuElements.isEmpty) ecuElements = document.findAllElements('SGBM');

      for (var ecuNode in ecuElements) {
        final ecu = SVTEcuData();

        // Get Name (baseVariant attribute or NAME tag)
        final baseVariant = _firstAttr(ecuNode, [
          'baseVariant',
          'basevariant',
          'variantName',
          'name',
          'ECU_GROBNAME',
        ]);
        if (baseVariant != null) {
          ecu.name = baseVariant;
        } else {
          ecu.name =
              _childText(ecuNode, ['NAME', 'ecuVariantName', 'ECU_GROBNAME']) ??
              '';
        }

        // Get Address
        // 1. <diagnosticAddress physicalOffset="XX"/>
        final diagAddrNode = ecuNode
            .findAllElements('diagnosticAddress')
            .firstOrNull;
        if (diagAddrNode != null) {
          final offset = diagAddrNode.getAttribute('physicalOffset');
          if (offset != null) {
            ecu.address = _parseAddressFlexible(offset);
          }
          if (ecu.address == 0) {
            final offset2 = diagAddrNode.getAttribute('PhysicalOffset');
            ecu.address = _parseAddressFlexible(offset2);
          }
        } else {
          // 2. DIAGNOSE_ADRESSE="XX" attribute (Legacy)
          final diagAttr = ecuNode.getAttribute('DIAGNOSE_ADRESSE');
          if (diagAttr != null) {
            ecu.address = _parseAddressFlexible(diagAttr);
          }
        }

        // 3. Alternative address tags/attributes
        if (ecu.address == 0) {
          final diagAlt = _firstAttr(ecuNode, [
            'diagAddress',
            'diagAddr',
            'DIAGADR',
          ]);
          ecu.address = _parseAddressFlexible(diagAlt);
        }

        void addSgbmId(String? sgbm) {
          final s = (sgbm ?? '').trim();
          if (s.isEmpty) return;
          final part = ECUPart.fromSgbmId(s);
          if (part == null) return;
          // avoid duplicates
          final key = part.sgbmId?.toUpperCase();
          if (key != null &&
              ecu.parts.any((p) => (p.sgbmId ?? '').toUpperCase() == key)) {
            return;
          }
          ecu.parts.add(part);
        }

        // Parse Parts (partIdentification / standardSVK / SWE / SGBMID tags)
        final partNodes = ecuNode.findAllElements('partIdentification');
        for (final partNode in partNodes) {
          final pc =
              _childText(partNode, ['processClass', 'ProcessClass', 'class']) ??
              _firstAttr(partNode, ['processClass', 'ProcessClass', 'class']);
          final id =
              _childText(partNode, ['id', 'ID', 'Id']) ??
              _firstAttr(partNode, ['id', 'ID', 'Id']);
          final mainVer =
              _childText(partNode, ['mainVersion', 'MainVersion', 'main']) ??
              _firstAttr(partNode, ['mainVersion', 'MainVersion', 'main']) ??
              '0';
          final subVer =
              _childText(partNode, ['subVersion', 'SubVersion', 'sub']) ??
              _firstAttr(partNode, ['subVersion', 'SubVersion', 'sub']) ??
              '0';
          final patchVer =
              _childText(partNode, ['patchVersion', 'PatchVersion', 'patch']) ??
              _firstAttr(partNode, ['patchVersion', 'PatchVersion', 'patch']) ??
              '0';

          if (pc != null &&
              id != null &&
              pc.trim().isNotEmpty &&
              id.trim().isNotEmpty) {
            addSgbmId(
              '${pc.trim()}_${id.trim()}_${mainVer.trim()}_${subVer.trim()}_${patchVer.trim()}',
            );
          }
        }

        // Some SVT variants embed parts inside standardSVK/hweSvk/etc.
        for (final svkTag in ['standardSVK', 'hweSvk', 'cafdSvk', 'sgbmSvk']) {
          for (final svkNode in ecuNode.findAllElements(svkTag)) {
            for (final partNode in svkNode.findAllElements(
              'partIdentification',
            )) {
              final pc =
                  _childText(partNode, [
                    'processClass',
                    'ProcessClass',
                    'class',
                  ]) ??
                  _firstAttr(partNode, [
                    'processClass',
                    'ProcessClass',
                    'class',
                  ]);
              final id =
                  _childText(partNode, ['id', 'ID', 'Id']) ??
                  _firstAttr(partNode, ['id', 'ID', 'Id']);
              final mainVer =
                  _childText(partNode, [
                    'mainVersion',
                    'MainVersion',
                    'main',
                  ]) ??
                  _firstAttr(partNode, [
                    'mainVersion',
                    'MainVersion',
                    'main',
                  ]) ??
                  '0';
              final subVer =
                  _childText(partNode, ['subVersion', 'SubVersion', 'sub']) ??
                  _firstAttr(partNode, ['subVersion', 'SubVersion', 'sub']) ??
                  '0';
              final patchVer =
                  _childText(partNode, [
                    'patchVersion',
                    'PatchVersion',
                    'patch',
                  ]) ??
                  _firstAttr(partNode, [
                    'patchVersion',
                    'PatchVersion',
                    'patch',
                  ]) ??
                  '0';

              if (pc != null &&
                  id != null &&
                  pc.trim().isNotEmpty &&
                  id.trim().isNotEmpty) {
                addSgbmId(
                  '${pc.trim()}_${id.trim()}_${mainVer.trim()}_${subVer.trim()}_${patchVer.trim()}',
                );
              }
            }
          }
        }

        // Legacy format (<SWE><SGBM_ID>...</SGBM_ID></SWE>)
        for (final sweNode in ecuNode.findAllElements('SWE')) {
          final sgbmIdNode =
              sweNode.findAllElements('SGBM_ID').firstOrNull ??
              sweNode.findAllElements('SGBMID').firstOrNull;
          if (sgbmIdNode != null) addSgbmId(sgbmIdNode.innerText);
        }

        // Another common format: <sgbmid>...</sgbmid>
        for (final sgbmNode in ecuNode.findAllElements('sgbmid')) {
          // Some files store full string in text
          final direct = sgbmNode.innerText.trim();
          if (direct.contains('_') && direct.split('_').length >= 5) {
            addSgbmId(direct);
          } else {
            final pc = _childText(sgbmNode, [
              'processClass',
              'ProcessClass',
              'class',
            ]);
            final id = _childText(sgbmNode, ['id', 'ID', 'Id']);
            final mainVer =
                _childText(sgbmNode, ['mainVersion', 'MainVersion', 'main']) ??
                '0';
            final subVer =
                _childText(sgbmNode, ['subVersion', 'SubVersion', 'sub']) ??
                '0';
            final patchVer =
                _childText(sgbmNode, [
                  'patchVersion',
                  'PatchVersion',
                  'patch',
                ]) ??
                '0';
            if (pc != null && id != null) {
              addSgbmId(
                '${pc.trim()}_${id.trim()}_${mainVer.trim()}_${subVer.trim()}_${patchVer.trim()}',
              );
            }
          }
        }

        // Add ECU if it has either address/name/parts (helps diagnostics even if parts missing)
        if (ecu.address > 0 || ecu.name.isNotEmpty || ecu.parts.isNotEmpty) {
          ecus.add(ecu);
        }
      }

      debugPrint('SVT loaded: VIN=$vin, I-Step=$iStep, ECUs=${ecus.length}');
    } catch (e) {
      debugPrint('Error parsing SVT XML: $e');
      _loadFromXmlRegex(xmlContent);
    }
  }

  void _loadFromXmlRegex(String xmlContent) {
    // Parse VIN
    final vinMatch = RegExp(r'<VIN[^>]*>([^<]+)</VIN>').firstMatch(xmlContent);
    if (vinMatch != null) {
      vin = vinMatch.group(1)!;
    }

    // Parse I-Step
    final iStepMatch = RegExp(
      r'<I_STUFE_IST[^>]*>([^<]+)</I_STUFE_IST>',
    ).firstMatch(xmlContent);
    if (iStepMatch != null) {
      iStep = iStepMatch.group(1)!;
    }

    // Parse ECUs
    final ecuMatches = RegExp(
      r'<ECU[^>]*>(.*?)</ECU>',
      dotAll: true,
    ).allMatches(xmlContent);
    for (var match in ecuMatches) {
      final ecuXml = match.group(1)!;
      final ecu = SVTEcuData();

      // Get ECU name/address
      final nameMatch = RegExp(r'<NAME[^>]*>([^<]+)</NAME>').firstMatch(ecuXml);
      if (nameMatch != null) {
        ecu.name = nameMatch.group(1)!;
      }

      final addrMatch = RegExp(
        r'DIAGNOSE_ADRESSE="([^"]+)"',
      ).firstMatch(ecuXml);
      if (addrMatch != null) {
        ecu.address = int.tryParse(addrMatch.group(1)!, radix: 16) ?? 0;
      }

      // Parse SWE (Software Elements)
      final sweMatches = RegExp(
        r'<SWE[^>]*>(.*?)</SWE>',
        dotAll: true,
      ).allMatches(ecuXml);
      for (var sweMatch in sweMatches) {
        final sweXml = sweMatch.group(1)!;
        final sgbmMatch = RegExp(
          r'<SGBM_ID[^>]*>([^<]+)</SGBM_ID>',
        ).firstMatch(sweXml);
        if (sgbmMatch != null) {
          final part = ECUPart.fromSgbmId(sgbmMatch.group(1)!);
          if (part != null) {
            ecu.parts.add(part);
          }
        }
      }

      if (ecu.parts.isNotEmpty) {
        ecus.add(ecu);
      }
    }
  }
}

/// ECU data from SVT
class SVTEcuData {
  String name = '';
  String baseVariant = '';
  int address = 0;
  List<ECUPart> parts = [];
}

/// Virtual ECU - Full BMW Protocol Implementation
class VirtualECU implements UdsEcu {
  final int diagAddress;
  final String name;

  // ECU state
  int _sessionType = 0x01;
  int _securityLevel = 0;
  bool _testerPresent = false;
  final List<int> _activeDTCs = [];

  // Mapping/handlers (service/DID/routine overrides)
  final UdsMappingRegistry mapping = UdsMappingRegistry();

  // UDS session key-value store (for handler state, counters, flashing state...)
  final Map<String, Object?> _udsSession = {};

  // Vehicle data
  FAData? faData;
  SVTData? svtData;
  String vin = 'WBA00000000000000';
  String iStep = 'G030-23-07-550';

  // ECU Parts (SVK components)
  final List<ECUPart> _parts = [];

  // DIDs storage - maps DID number to data
  final Map<int, Uint8List> _dids = {};

  // CAFD data storage (DID 0x1000 - 0x1FFF)
  final Map<int, Uint8List> _cafdData = {};

  // Routine results storage
  final Map<int, Uint8List> _routineResults = {};

  /// Get current session type
  int get session => _sessionType;

  @override
  int get sessionType => _sessionType;

  @override
  int get securityLevel => _securityLevel;

  @override
  Map<String, Object?> get udsSession => _udsSession;

  /// Get ECU parts
  List<ECUPart> get parts => List.unmodifiable(_parts);

  /// Get active DTCs
  List<int> get activeDTCs => List.unmodifiable(_activeDTCs);

  /// Get variant coding
  String get variantCoding => '';

  /// Get coding data
  Map<int, Uint8List> get codingData => _cafdData;

  /// Add an ECU part (CAFD, SWFL, BTLD)
  void addPart(ECUPart part) {
    _parts.add(part);
    // Rebuild SVK when parts change
    _rebuildSVK();
  }

  /// Rebuild SVK from parts
  void _rebuildSVK() {
    if (_parts.isEmpty) return;
    final svk = _buildSVKFromParts(_parts);
    _dids[0xF150] = svk;
    _dids[0xF101] = svk;
  }

  /// Build SVK from parts list
  Uint8List _buildSVKFromParts(List<ECUPart> parts) {
    final buffer = <int>[];

    // SVK header
    // BMW SVK typically uses version 0x01
    buffer.add(0x01); // Version
    // Part count is 1 byte
    buffer.add(parts.length.clamp(0, 255));

    // Add each part
    for (final part in parts) {
      buffer.addAll(part.toBytes());
    }

    return Uint8List.fromList(buffer);
  }

  /// Get DID value
  @override
  Uint8List? getDID(int did) => _dids[did];

  /// Add a DTC (Diagnostic Trouble Code)
  void addDTC(int dtc) {
    if (!_activeDTCs.contains(dtc)) {
      _activeDTCs.add(dtc);
    }
  }

  /// Clear all DTCs
  void clearDTCs() {
    _activeDTCs.clear();
  }

  VirtualECU({required this.diagAddress, this.name = 'VirtualECU'}) {
    _initDefaultDids();
  }

  /// Initialize default BMW DIDs
  void _initDefaultDids() {
    // F186 - Active Session
    _dids[0xF186] = Uint8List.fromList([0x01]);

    // F187 - ECU Manufacturing Part Number
    _dids[0xF187] = Uint8List.fromList('8736849-01'.padRight(12).codeUnits);

    // F189 - ECU Software Version
    _dids[0xF189] = Uint8List.fromList('V1.00.00'.padRight(16).codeUnits);

    // F18A - System Supplier ECU Software Number
    _dids[0xF18A] = Uint8List.fromList('PSDZ_SIM'.padRight(12).codeUnits);

    // F18B - ECU Manufacturing Date
    _dids[0xF18B] = Uint8List.fromList([0x20, 0x24, 0x01, 0x15]);

    // F18C - ECU Serial Number
    _dids[0xF18C] = Uint8List.fromList('0000000001234567'.codeUnits);

    // F190 - VIN (will be updated from FA)
    _dids[0xF190] = Uint8List.fromList(vin.padRight(17).codeUnits);

    // F191 - ECU Hardware Number
    _dids[0xF191] = Uint8List.fromList('8736849'.padRight(10).codeUnits);

    // F192 - ECU Hardware Version
    _dids[0xF192] = Uint8List.fromList('01'.codeUnits);

    // F193 - System Supplier ECU Hardware Number
    _dids[0xF193] = Uint8List.fromList('SIM-HW-01'.padRight(12).codeUnits);

    // F194 - System Supplier ECU Hardware Version
    _dids[0xF194] = Uint8List.fromList('01'.codeUnits);

    // F195 - System Supplier ECU Software Version
    _dids[0xF195] = Uint8List.fromList('01.00'.codeUnits);

    // 2503-2505 - I-Step (Shipment/Current/Last)
    final iStepBytes = Uint8List.fromList(
      iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
    );
    _dids[0x2503] = iStepBytes;
    _dids[0x2504] = iStepBytes;
    _dids[0x2505] = iStepBytes;

    // 3F06, 100B, 100C, 100D - E-Sys I-Step formats
    _dids[0x3F06] = iStepBytes;
    _dids[0x100B] = iStepBytes;
    _dids[0x100C] = iStepBytes;
    _dids[0x100D] = iStepBytes;

    // F150 - SVK (will be built from SVT)
    final defaultSVK = _buildDefaultSVK();
    _dids[0xF150] = defaultSVK;
    _dids[0xF101] = defaultSVK; // SVK-Ist / SGBM-IDs

    // 631F - Programming Counter
    _dids[0x631F] = Uint8List.fromList([0x00, 0x00]);

    // F17C - Variant Coding Index
    _dids[0xF17C] = Uint8List.fromList([0x01]);

    // 172A - Bluetooth MAC Address (Dummy)
    // Format: 6 bytes MAC + 7 bytes padding/status = 13 bytes
    // Based on log: 00 A9 FE FF 64 FF FF FF 00 A9 FE FF 01
    _dids[0x172A] = Uint8List.fromList([
      0x00, 0xA9, 0xFE, 0xFF, 0x64, 0xFF, // MAC/IP part 1
      0xFF, 0xFF, 0x00, 0xA9, 0xFE, 0xFF, 0x01, // Padding/IP part 2
    ]);

    // 172B - WLAN MAC Address (Dummy)
    // Format: 6 bytes MAC + 7 bytes padding/status = 13 bytes
    _dids[0x172B] = Uint8List.fromList([
      0x00, 0xA9, 0xFE, 0xFF, 0x64, 0xFF, // MAC/IP part 1
      0xFF,
      0xFF,
      0x00,
      0xA9,
      0xFE,
      0xFF,
      0x02, // Padding/IP part 2 (slightly different)
    ]);

    // Initialize FA DIDs with minimal FA (so E-Sys can read something even if no vehicle loaded)
    final minimalFA = _buildMinimalFA();
    _dids[0x3FD0] = minimalFA;
    _dids[0x1769] = minimalFA;
    _dids[0xD100] = minimalFA;

    // === Additional DIDs for FeatureInstaller compatibility ===

    // F1A0 - Hardware Version
    _dids[0xF1A0] = Uint8List.fromList('HW01.00'.padRight(16).codeUnits);

    // F1A1 - Software Version
    _dids[0xF1A1] = Uint8List.fromList('SW01.00'.padRight(16).codeUnits);

    // F1A2 - Calibration Version
    _dids[0xF1A2] = Uint8List.fromList('CAL01.00'.padRight(16).codeUnits);

    // F1D0 - Boot Software Identification
    _dids[0xF1D0] = Uint8List.fromList('BTLD_V1.0'.padRight(16).codeUnits);

    // F1D1 - Application Software Identification
    _dids[0xF1D1] = Uint8List.fromList('APP_V1.0'.padRight(16).codeUnits);

    // F1DF - Program Information
    _dids[0xF1DF] = Uint8List.fromList([0x01, 0x00, 0x00, 0x00]);

    // 200A-200F - System Status DIDs
    _dids[0x200A] = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
    _dids[0x200B] = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
    _dids[0x200C] = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);

    // F1B0-F1B2 - ECU Calibration
    _dids[0xF1B0] = Uint8List.fromList('CAL001'.padRight(12).codeUnits);
    _dids[0xF1B1] = Uint8List.fromList('CAL002'.padRight(12).codeUnits);
    _dids[0xF1B2] = Uint8List.fromList('CAL003'.padRight(12).codeUnits);

    // 6310 - Hardware Information
    _dids[0x6310] = Uint8List.fromList([0x01, 0x00, 0x01, 0x00]);

    // F111 - ECU Hardware-Software Compatibility
    _dids[0xF111] = Uint8List.fromList([0x01]);

    // === NBT EVO Specific DIDs from all_data.txt ===
    // These are real responses captured from BMW NBT EVO (0x63)

    // 1735 - NBT Status
    // From log: 62173500 -> Status OK
    _dids[0x1735] = Uint8List.fromList([0x00]);

    // 1736 - NBT Mode
    _dids[0x1736] = Uint8List.fromList([0x01, 0x00]);

    // 1737 - NBT Feature Status
    _dids[0x1737] = Uint8List.fromList([0xFF, 0xFF]);

    // 1738 - NBT Configuration
    _dids[0x1738] = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);

    // 1010 - ECU Identification
    _dids[0x1010] = Uint8List.fromList([0x00, 0x63]); // HU address

    // 1011 - Supplier Code
    _dids[0x1011] = Uint8List.fromList('BMW-HU'.padRight(16).codeUnits);

    // F188 - ECU Software Number
    _dids[0xF188] = Uint8List.fromList(
      'HU_NBT_EVO'.padRight(24, '\x00').codeUnits.take(24).toList(),
    );

    // F199 - Programming Date
    _dids[0xF199] = Uint8List.fromList([0x20, 0x25, 0x03, 0x28]); // 2025-03-28

    // F19E - Extended VIN
    _dids[0xF19E] = Uint8List.fromList(vin.padRight(17, '\x00').codeUnits);

    // 2000 - NBT Activation Status
    _dids[0x2000] = Uint8List.fromList([0x01]); // Activated

    // 2001 - NBT Feature Enablement
    _dids[0x2001] = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);

    // 3000 - Coding Data Status
    _dids[0x3000] = Uint8List.fromList([0x00]); // Coded

    // 6000 - Diagnostic Status
    _dids[0x6000] = Uint8List.fromList([0x00, 0x00]); // No errors

    // === DME/Engine Specific DIDs ===
    // 2500 - Engine Running Status
    _dids[0x2500] = Uint8List.fromList([0x00]); // Engine off

    // 2501 - Engine Temperature
    _dids[0x2501] = Uint8List.fromList([0x62]); // ~58C

    // 2502 - Engine RPM
    _dids[0x2502] = Uint8List.fromList([0x00, 0x00]); // 0 RPM
  }

  /// Load configuration from SVT data
  void loadFromSVT(SVTData svt) {
    svtData = svt;
    if (svt.vin.isNotEmpty) vin = svt.vin;
    if (svt.iStep.isNotEmpty) iStep = svt.iStep;

    // Update VIN DID
    _dids[0xF190] = Uint8List.fromList(vin.padRight(17).codeUnits);

    // Update I-Step DIDs
    final iStepBytes = Uint8List.fromList(
      iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
    );
    _dids[0x2503] = iStepBytes;
    _dids[0x2504] = iStepBytes;
    _dids[0x2505] = iStepBytes;
    _dids[0x3F06] = iStepBytes;
    _dids[0x100B] = iStepBytes;
    _dids[0x100C] = iStepBytes;
    _dids[0x100D] = iStepBytes;

    // Find ECU in SVT
    try {
      final ecuData = svt.ecus.firstWhere((e) => e.address == diagAddress);
      if (ecuData.parts.isNotEmpty) {
        // Build SVK from parts
        final svkBytes = _buildSVKFromParts(ecuData.parts);
        _dids[0xF150] = svkBytes;
        _dids[0xF101] = svkBytes;
      }
    } catch (e) {
      // ECU not found in SVT, keep default
    }
  }

  /// Load configuration from FA data
  void loadFAData(FAData fa) {
    faData = fa;
    if (fa.vin.isNotEmpty) vin = fa.vin;

    // Update VIN DID
    _dids[0xF190] = Uint8List.fromList(vin.padRight(17).codeUnits);

    // Update FA DIDs
    final faBytes = fa.toBinary();
    _dids[0x3FD0] = faBytes;
    _dids[0xD100] = faBytes;
    _dids[0x1769] = faBytes;
  }

  /// Build default SVK when no SVT is loaded
  Uint8List _buildDefaultSVK() {
    final buffer = <int>[];

    // SVK Version (1 byte)
    buffer.add(0x01);

    // Create dummy parts for HU (Head Unit) simulation
    // 1. BTLD (Bootloader)
    final btld = ECUPart(
      processClass: ProcessClass.btld,
      id: 0x00001234,
      version: 0x00100200,
    );

    // 2. SWFL (Software)
    final swfl = ECUPart(
      processClass: ProcessClass.swfl,
      id: 0x00005678,
      version: 0x00100200,
    );

    // 3. CAFD (Coding Data)
    final cafd = ECUPart(
      processClass: ProcessClass.cafd,
      id: 0x00009ABC,
      version: 0x00100200,
    );

    // Number of parts (1 byte)
    buffer.add(0x03);

    buffer.addAll(btld.toBytes());
    buffer.addAll(swfl.toBytes());
    buffer.addAll(cafd.toBytes());

    return Uint8List.fromList(buffer);
  }

  /// Build default FP (Feature Profile) - Minimal
  Uint8List _buildDefaultFP() {
    final buffer = <int>[];

    // FP Version (1 byte)
    buffer.add(0x01);

    // Category count (1 byte)
    buffer.add(0x00);

    return Uint8List.fromList(buffer);
  }

  /// Build SVK from loaded SVT data - uses only THIS ECU's parts
  Uint8List _buildSVK() {
    if (svtData == null || svtData!.ecus.isEmpty) {
      return _buildDefaultSVK();
    }

    // Find THIS ECU's data in SVT
    SVTEcuData? myEcuData;
    try {
      myEcuData = svtData!.ecus.firstWhere((e) => e.address == diagAddress);
    } catch (_) {
      // ECU not found in SVT, use default
      return _buildDefaultSVK();
    }

    if (myEcuData.parts.isEmpty) {
      return _buildDefaultSVK();
    }

    return _buildSVKFromParts(myEcuData.parts);
  }

  /// Load FA data and update DIDs
  void loadFA(FAData fa) {
    faData = fa;
    vin = fa.vin;

    // Update VIN DID
    _dids[0xF190] = Uint8List.fromList(
      vin.padRight(17).codeUnits.take(17).toList(),
    );

    // Update FA DIDs - Raw FA for E-Sys (no length prefix)
    final faBinary = fa.toBinaryVCM();
    _dids[0x1769] = faBinary; // VCM FA for E-Sys MCD3_ReadFAFromVCM

    // FA with length prefix for other DIDs
    final faBinaryWithLen = fa.toBinaryWithLength();
    _dids[0x3FD0] = faBinaryWithLen; // FA Data (with length)
    _dids[0xD100] = faBinary; // FA (raw)

    // === E-Sys VCM Specific DIDs ===
    // FA_Teil1 (0x3F1C) - First part of FA for VCM jobs
    // FA_Teil2 (0x3F1D) - Second part of FA for VCM jobs
    // Split FA data for E-Sys compatibility (some jobs read in parts)
    final halfLen = (faBinary.length / 2).ceil();
    _dids[0x3F1C] = Uint8List.fromList(faBinary.take(halfLen).toList());
    _dids[0x3F1D] = Uint8List.fromList(faBinary.skip(halfLen).toList());

    // VCM Status DIDs - Tell E-Sys that FA is valid and stored
    _dids[0xF1D0] = Uint8List.fromList([0x01]); // VCM Status: FA stored
    _dids[0xF1D1] = Uint8List.fromList([0x01]); // VCM Backup exists
    _dids[0xF1D2] = Uint8List.fromList([0x01]); // VCM Master exists
    _dids[0x3F19] = Uint8List.fromList([0x01, 0x00]); // VcmVcmIdentification

    // Update FP DIDs (Minimal FP)
    final fpBinary = _buildDefaultFP();
    _dids[0xD101] = fpBinary; // FP Data
    _dids[0x3FE0] = fpBinary; // FP Data

    // Update I-Step if series is different from default
    if (fa.series.isNotEmpty && !iStep.startsWith(fa.series)) {
      // Construct a plausible I-Step for this series
      // Format: SSSS-YY-MM-VVV (e.g. G020-23-07-550)
      // Use current date or fixed date
      iStep = '${fa.series}-23-07-550';

      final iStepBytes = Uint8List.fromList(
        iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      );
      _dids[0x2503] = iStepBytes;
      _dids[0x2504] = iStepBytes;
      _dids[0x2505] = iStepBytes;
      _dids[0x3F06] = iStepBytes;
      _dids[0x100B] = iStepBytes;
      _dids[0x100C] = iStepBytes;
      _dids[0x100D] = iStepBytes;

      debugPrint('VirtualECU: I-Step updated from FA Series: $iStep');
    }

    debugPrint(
      'VirtualECU: FA loaded, VIN=$vin, FA size=${faBinary.length} bytes',
    );
  }

  /// Load SVT data and update DIDs
  void loadSVT(SVTData svt) {
    svtData = svt;

    if (svt.vin.isNotEmpty) {
      vin = svt.vin;
      _dids[0xF190] = Uint8List.fromList(
        vin.padRight(17).codeUnits.take(17).toList(),
      );
    }

    if (svt.iStep.isNotEmpty) {
      iStep = svt.iStep;
      final iStepBytes = Uint8List.fromList(
        iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
      );
      _dids[0x2503] = iStepBytes;
      _dids[0x2504] = iStepBytes;
      _dids[0x2505] = iStepBytes;
      _dids[0x3F06] = iStepBytes;
      _dids[0x100B] = iStepBytes;
      _dids[0x100C] = iStepBytes;
      _dids[0x100D] = iStepBytes;
    }

    // Build and store SVK
    _dids[0xF150] = _buildSVK();

    debugPrint(
      'VirtualECU: SVT loaded, I-Step=$iStep, Parts=${svtData?.ecus.fold(0, (sum, e) => sum + e.parts.length)}',
    );
  }

  /// Build ECU Identification for ISTA (DID 0x1010)
  Uint8List _buildECUIdentification() {
    final buffer = <int>[];

    // ECU Identification structure for ISTA:
    // [0] - Diagnostic Address
    buffer.add(diagAddress);

    // [1-2] - Hardware Version (2 bytes)
    buffer.addAll([0x01, 0x00]);

    // [3-4] - Software Version (2 bytes)
    buffer.addAll([0x01, 0x00]);

    // [5-24] - ECU Name (20 bytes, null padded)
    buffer.addAll(name.padRight(20, '\x00').codeUnits.take(20));

    // [25-44] - Supplier Code (20 bytes, null padded)
    buffer.addAll('BMW AG'.padRight(20, '\x00').codeUnits.take(20));

    // [45-64] - Hardware Part Number (20 bytes)
    final hwPartNum = '8888888';
    buffer.addAll(hwPartNum.padRight(20, '\x00').codeUnits.take(20));

    // [65-84] - Software Part Number (20 bytes)
    buffer.addAll(name.padRight(20, '\x00').codeUnits.take(20));

    return Uint8List.fromList(buffer);
  }

  /// Build ISTA ECU Identification (DID 0xF110)
  Uint8List _buildISTAECUIdent() {
    final buffer = <int>[];

    // VIN (17 bytes)
    buffer.addAll(vin.padRight(17, '\x00').codeUnits.take(17));

    // ECU Name (20 bytes)
    buffer.addAll(name.padRight(20, '\x00').codeUnits.take(20));

    // Diagnostic Address (1 byte)
    buffer.add(diagAddress);

    // Hardware Version (2 bytes)
    buffer.addAll([0x01, 0x00]);

    // Software Version (2 bytes)
    buffer.addAll([0x01, 0x00]);

    // I-Step (24 bytes)
    buffer.addAll(iStep.padRight(24, '\x00').codeUnits.take(24));

    return Uint8List.fromList(buffer);
  }

  /// Load CAFD coding data (DID 0x1000-0x1FFF)
  void loadCAFDData(int did, Uint8List data) {
    if (did >= 0x1000 && did <= 0x1FFF) {
      _cafdData[did] = data;
    }
  }

  /// Set custom DID data
  @override
  void setDID(int did, Uint8List data) {
    _dids[did] = data;
  }

  /// Process UDS request and return response
  Uint8List? processRequest(Uint8List request) {
    if (request.isEmpty) return _negativeResponse(0x00, 0x10);

    final serviceId = request[0];

    // Allow mapping registry to override any service.
    // If handler returns null -> fall back to default switch below.
    final mapped = mapping.handleService(this, serviceId, request);
    if (mapped != null) {
      return mapped;
    }

    switch (serviceId) {
      case 0x10: // Diagnostic Session Control
        return _handleSessionControl(request);

      case 0x11: // ECU Reset
        return _handleECUReset(request);

      case 0x14: // Clear Diagnostic Information
        return _handleClearDTC(request);

      case 0x19: // Read DTC Information
        return _handleReadDTC(request);

      case 0x22: // Read Data By Identifier
        return _handleReadDID(request);

      case 0x23: // Read Memory By Address
        return _handleReadMemory(request);

      case 0x27: // Security Access
        return _handleSecurityAccess(request);

      case 0x28: // Communication Control
        return _handleCommunicationControl(request);

      case 0x2E: // Write Data By Identifier
        return _handleWriteDID(request);

      case 0x2F: // Input Output Control
        return _handleIOControl(request);

      case 0x31: // Routine Control
        return _handleRoutineControl(request);

      case 0x34: // Request Download
        return _handleRequestDownload(request);

      case 0x35: // Request Upload
        return _handleRequestUpload(request);

      case 0x36: // Transfer Data
        return _handleTransferData(request);

      case 0x37: // Request Transfer Exit
        return _handleTransferExit(request);

      case 0x3D: // Write Memory By Address
        return _handleWriteMemory(request);

      case 0x3E: // Tester Present
        return _handleTesterPresent(request);

      case 0x85: // Control DTC Setting
        return _handleControlDTCSetting(request);

      case 0x1A: // KWP2000 Read ECU Identification
        return _handleKWP2000ReadECUID(request);

      case 0x01: // OBD-II Mode 01 - Current Data
        return _handleOBDMode01(request);

      case 0x03: // OBD-II Mode 03 - Read DTCs
        return _handleOBDMode03(request);

      case 0x04: // OBD-II Mode 04 - Clear DTCs
        return _handleOBDMode04(request);

      case 0x09: // OBD-II Mode 09 - Vehicle Information
        return _handleOBDMode09(request);

      default:
        return _negativeResponse(serviceId, 0x11); // Service not supported
    }
  }

  // === UDS Service Handlers ===

  /// Handle Diagnostic Session Control (0x10)
  /// From all_data.txt:
  /// - 1001 -> 5001 (Default Session)
  /// - 1002 -> 5002 (Programming Session)
  /// - 1003 -> 5003 (Extended Diagnostic Session)
  Uint8List _handleSessionControl(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x10, 0x13);

    _sessionType = request[1];
    _dids[0xF186] = Uint8List.fromList([_sessionType]);

    // Session-specific handling
    switch (_sessionType) {
      case 0x01: // Default Session
        // Reset security level when returning to default
        _securityLevel = 0;
        break;
      case 0x02: // Programming Session
        // May require security access
        break;
      case 0x03: // Extended Diagnostic Session
        // Full diagnostic access
        break;
      case 0x40: // BMW Coding Session
        break;
      case 0x41: // BMW Development Session
        break;
      case 0x60: // BMW EOL Session
        break;
    }

    // Positive response with timing parameters
    // Format: 50 [SessionType] [P2 High] [P2 Low] [P2* High] [P2* Low]
    return Uint8List.fromList([
      0x50,
      _sessionType,
      0x00, 0x32, // P2 timing (50ms)
      0x01, 0xF4, // P2* timing (5000ms)
    ]);
  }

  Uint8List _handleECUReset(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x11, 0x13);

    final resetType = request[1];

    // Reset session state
    _sessionType = 0x01;
    _securityLevel = 0;
    _dids[0xF186] = Uint8List.fromList([0x01]);

    return Uint8List.fromList([0x51, resetType]);
  }

  Uint8List _handleClearDTC(Uint8List request) {
    // From log: 14FFFFFF -> 54 (positive response)
    // BMW format: 14 [GroupOfDTC 3 bytes]
    _activeDTCs.clear();
    return Uint8List.fromList([0x54]);
  }

  Uint8List _handleReadDTC(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x19, 0x13);

    final subFunc = request[1];

    switch (subFunc) {
      case 0x01: // Report Number of DTC by Status Mask
        // From log: 1901FF -> 5901 response
        return Uint8List.fromList([
          0x59,
          0x01,
          0xFF, // Status Availability Mask
          0x00, // DTC Format Identifier (ISO15031-6)
          (_activeDTCs.length >> 8) & 0xFF,
          _activeDTCs.length & 0xFF,
        ]);

      case 0x02: // Report DTC by Status Mask
        // From log: 1902AF -> 5902FF[DTCs]
        // If no DTCs, return 59 02 [StatusAvailabilityMask]
        if (_activeDTCs.isEmpty) {
          return Uint8List.fromList([0x59, 0x02, 0xFF]);
        }

        final response = <int>[0x59, 0x02, 0xFF];
        for (var dtc in _activeDTCs) {
          response.addAll([
            (dtc >> 16) & 0xFF,
            (dtc >> 8) & 0xFF,
            dtc & 0xFF,
            0x2F, // Status: confirmed, active, stored
          ]);
        }
        return Uint8List.fromList(response);

      case 0x03: // Report DTC Snapshot Identifier
        return Uint8List.fromList([0x59, 0x03, 0xFF, 0x00]);

      case 0x04: // Report DTC Snapshot Record by DTC Number
        return Uint8List.fromList([0x59, 0x04, 0xFF]);

      case 0x06: // Report DTC Extended Data Record by DTC Number
        return Uint8List.fromList([0x59, 0x06, 0xFF]);

      case 0x0A: // Report Supported DTC
        if (_activeDTCs.isEmpty) {
          return Uint8List.fromList([0x59, 0x0A, 0xFF]);
        }
        final response = <int>[0x59, 0x0A, 0xFF];
        for (var dtc in _activeDTCs) {
          response.addAll([
            (dtc >> 16) & 0xFF,
            (dtc >> 8) & 0xFF,
            dtc & 0xFF,
            0x2F,
          ]);
        }
        return Uint8List.fromList(response);

      case 0x0B: // Report First Test Failed DTC
      case 0x0C: // Report First Confirmed DTC
      case 0x0D: // Report Most Recent Test Failed DTC
      case 0x0E: // Report Most Recent Confirmed DTC
        if (_activeDTCs.isEmpty) {
          return Uint8List.fromList([0x59, subFunc, 0xFF]);
        }
        final dtc = _activeDTCs.first;
        return Uint8List.fromList([
          0x59,
          subFunc,
          0xFF,
          (dtc >> 16) & 0xFF,
          (dtc >> 8) & 0xFF,
          dtc & 0xFF,
          0x2F,
        ]);

      case 0x14: // Report DTC Fault Detection Counter
        return Uint8List.fromList([0x59, 0x14, 0xFF]);

      case 0xAF: // Extended status mask (BMW specific)
        // From log: 1902AF -> returns DTC list
        if (_activeDTCs.isEmpty) {
          return Uint8List.fromList([0x59, 0x02, 0xFF]);
        }
        final response = <int>[0x59, 0x02, 0xFF];
        for (var dtc in _activeDTCs) {
          response.addAll([
            (dtc >> 16) & 0xFF,
            (dtc >> 8) & 0xFF,
            dtc & 0xFF,
            0x2F,
          ]);
        }
        return Uint8List.fromList(response);

      default:
        return Uint8List.fromList([0x59, subFunc, 0xFF]);
    }
  }

  Uint8List _handleReadDID(Uint8List request) {
    if (request.length < 3) return _negativeResponse(0x22, 0x13);

    final response = <int>[0x62];
    var pos = 1;

    // Treat empty DID values as "not supported" to avoid malformed positive
    // responses like: 62 <DID> (no payload). Some testers (ISTA) interpret
    // that as a disturbed transmission / data error.
    Uint8List? getNonEmptyDid(int did) {
      final v = _dids[did];
      if (v == null || v.isEmpty) return null;
      return v;
    }

    // If only one DID is requested, UDS expects an NRC when DID is not supported.
    // BMW sometimes batches multiple DIDs; in that case we skip unknown DIDs
    // instead of returning a malformed partial entry.
    final isSingleDidRequest = request.length == 3;

    // Support multiple DIDs in one request (BMW/E-Sys feature)
    while (pos + 1 < request.length) {
      final did = (request[pos] << 8) | request[pos + 1];
      pos += 2;

      response.add((did >> 8) & 0xFF);
      response.add(did & 0xFF);

      // Mapping override for this DID.
      final mapped = mapping.handleDid(this, did, request);
      if (mapped != null) {
        response.addAll(mapped);
        continue;
      }

      // === DID 0x1769 - VCM FA for E-Sys ===
      // Must include length header for E-Sys compatibility
      if (did == 0x1769) {
        Uint8List faBytes;
        if (faData != null) {
          faBytes = faData!.toBinaryVCM();
          debugPrint(
            'VirtualECU[$name]: DID 0x1769 - Using faData (${faBytes.length} bytes)',
          );
        } else if (_dids.containsKey(0x1769)) {
          faBytes = _dids[0x1769]!;
          debugPrint(
            'VirtualECU[$name]: DID 0x1769 - Using _dids[0x1769] (${faBytes.length} bytes)',
          );
        } else if (_dids.containsKey(0x3FD0)) {
          faBytes = _dids[0x3FD0]!;
          debugPrint(
            'VirtualECU[$name]: DID 0x1769 - Using _dids[0x3FD0] (${faBytes.length} bytes)',
          );
        } else {
          // Build minimal FA with VIN only
          faBytes = _buildMinimalFA();
          debugPrint(
            'VirtualECU[$name]: DID 0x1769 - Using minimal FA (${faBytes.length} bytes)',
          );
        }
        // FA bytes already include the length header (from toBinaryVCM or _buildMinimalFA)
        response.addAll(faBytes);
        continue;
      }

      // === DIDs 0x100B-0x100D - E-Sys I-Step (24 bytes) ===
      if (did >= 0x100B && did <= 0x100D) {
        // Check _dids first, then fallback to iStep property
        final v = getNonEmptyDid(did);
        if (v != null) {
          response.addAll(v);
        } else {
          final iStepBytes = Uint8List.fromList(
            iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
          );
          response.addAll(iStepBytes);
        }
        continue;
      }

      // === DID 0x3F06 - I-Step Shipment for E-Sys ===
      if (did == 0x3F06) {
        // Check _dids first, then fallback to iStep property
        final v = getNonEmptyDid(0x3F06);
        if (v != null) {
          response.addAll(v);
        } else {
          final iStepBytes = Uint8List.fromList(
            iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
          );
          response.addAll(iStepBytes);
        }
        continue;
      }

      // === DID 0xF100 - Combined VIN + I-Step for System ID ===
      if (did == 0xF100) {
        final vinBytes = vin.padRight(17).codeUnits.take(17).toList();
        final iStepBytes = iStep
            .padRight(24, '\x00')
            .codeUnits
            .take(24)
            .toList();
        response.addAll(vinBytes);
        response.addAll(iStepBytes);
        continue;
      }

      // === DID 0xF150 - SVK ===
      if (did == 0xF150) {
        final v = getNonEmptyDid(0xF150);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll(_buildSVK());
        }
        continue;
      }

      // === DID 0xF101 - SVK-Ist / SGBM-IDs ===
      if (did == 0xF101) {
        final v101 = getNonEmptyDid(0xF101);
        if (v101 != null) {
          response.addAll(v101);
        } else {
          final v150 = getNonEmptyDid(0xF150);
          if (v150 != null) {
            response.addAll(v150);
          } else {
            response.addAll(_buildSVK());
          }
        }
        continue;
      }

      // === DID 0x1010 - ECU Identification (ISTA) ===
      if (did == 0x1010) {
        // ISTA expects ECU identification data
        final ecuIdent = _buildECUIdentification();
        response.addAll(ecuIdent);
        continue;
      }

      // === DID 0x1011 - Supplier Identifier ===
      if (did == 0x1011) {
        response.addAll('BMW AG'.padRight(20, '\x00').codeUnits.take(20));
        continue;
      }

      // === DID 0x1000-0x1FFF - CAFD Coding Data from NCD ===
      if (did >= 0x1000 && did <= 0x1FFF) {
        final cafdData = _cafdData[did];
        Uint8List? bytes;

        if (cafdData != null && cafdData.isNotEmpty) {
          // Return first 252 bytes max per E-Sys spec
          bytes = cafdData.length > 252 ? cafdData.sublist(0, 252) : cafdData;
        } else {
          bytes = getNonEmptyDid(did);
        }

        if (bytes != null && bytes.isNotEmpty) {
          response.addAll(bytes);
        } else {
          // No payload available -> treat as unsupported to avoid 62 DID (empty)
          if (response.length >= 3) {
            response.removeLast();
            response.removeLast();
          }
          if (isSingleDidRequest) {
            return _negativeResponse(0x22, 0x31);
          }
        }
        continue;
      }

      // === DID 0x3F07 - I-Step Current (ISTA) ===
      // This is the I-Step currently programmed/active on the vehicle
      if (did == 0x3F07) {
        final v = getNonEmptyDid(0x3F07);
        if (v != null) {
          response.addAll(v);
        } else {
          // Return same as 0x3F06 (I-Step Shipment) for current I-Step
          final iStepBytes = Uint8List.fromList(
            iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
          );
          response.addAll(iStepBytes);
        }
        continue;
      }

      // === DID 0x3F08 - I-Step Last (ISTA) ===
      if (did == 0x3F08) {
        final v = getNonEmptyDid(0x3F08);
        if (v != null) {
          response.addAll(v);
        } else {
          final iStepBytes = Uint8List.fromList(
            iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
          );
          response.addAll(iStepBytes);
        }
        continue;
      }

      // === DID 0x2503-0x2505 - I-Step (Shipment/Current/Last) ===
      if (did >= 0x2503 && did <= 0x2505) {
        // Check _dids first, then fallback to iStep property
        final v = getNonEmptyDid(did);
        if (v != null) {
          response.addAll(v);
        } else {
          final iStepBytes = Uint8List.fromList(
            iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
          );
          response.addAll(iStepBytes);
        }
        continue;
      }

      // === DID 0xF190 - VIN ===
      if (did == 0xF190) {
        // Check _dids first, then fallback to vin property
        final v = getNonEmptyDid(0xF190);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll(vin.padRight(17, '\x00').codeUnits.take(17));
        }
        debugPrint('VirtualECU[$name]: DID 0xF190 - VIN=$vin');
        continue;
      }

      // === DID 0xF1A0 - Extended VIN ===
      if (did == 0xF1A0) {
        response.addAll(vin.padRight(17, '\x00').codeUnits.take(17));
        continue;
      }

      // === DID 0xF110 - ECU Identification Data ===
      if (did == 0xF110) {
        // Used by ISTA for ECU identification
        final ecuId = _buildISTAECUIdent();
        response.addAll(ecuId);
        continue;
      }

      // === DID 0xF18C - ECU Serial Number ===
      if (did == 0xF18C) {
        final stored = _dids[0xF18C];
        final serial = (stored != null && stored.isNotEmpty)
            ? stored
            : Uint8List.fromList('1234567890'.padRight(20, '\x00').codeUnits);
        response.addAll(serial.take(20));
        continue;
      }

      // === DID 0xF186 - Active Diagnostic Session ===
      if (did == 0xF186) {
        // Return current session mode (default session = 0x01)
        response.add(_sessionType);
        continue;
      }

      // === DID 0xF187 - Vehicle Manufacturer Spare Part Number ===
      if (did == 0xF187) {
        final v = getNonEmptyDid(0xF187);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll(
            'SPARE_PART_NUM'.padRight(16, '\x00').codeUnits.take(16),
          );
        }
        continue;
      }

      // === DID 0xF189 - Vehicle Manufacturer ECU Software Version Number ===
      if (did == 0xF189) {
        final v = getNonEmptyDid(0xF189);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll(
            'SW_V001.00.00'.padRight(16, '\x00').codeUnits.take(16),
          );
        }
        continue;
      }

      // === DID 0xF18A - System Supplier Identifier ===
      if (did == 0xF18A) {
        final v = getNonEmptyDid(0xF18A);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll('BMW AG'.padRight(10, '\x00').codeUnits.take(10));
        }
        continue;
      }

      // === DID 0xF191 - Vehicle Manufacturer ECU Hardware Number ===
      if (did == 0xF191) {
        final v = getNonEmptyDid(0xF191);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll('HW_12345'.padRight(16, '\x00').codeUnits.take(16));
        }
        continue;
      }

      // === DID 0xF192 - Vehicle Manufacturer ECU Hardware Version Number ===
      if (did == 0xF192) {
        final v = getNonEmptyDid(0xF192);
        if (v != null) {
          response.addAll(v);
        } else {
          response.addAll('HW_V01.00'.padRight(16, '\x00').codeUnits.take(16));
        }
        continue;
      }

      // === DID 0x1001 - ECU Status (ISTA) ===
      if (did == 0x1001) {
        // ECU Status: 0x00 = OK, No Errors
        response.addAll([0x00, 0x00, 0x00, 0x00]);
        continue;
      }

      // === DID 0x1002 - ECU Supply Voltage Status ===
      if (did == 0x1002) {
        // Voltage OK (12V nominal = 0x78 = 120 * 0.1V)
        response.addAll([0x78, 0x00]);
        continue;
      }

      // Check stored DIDs
      final data = _dids[did];
      if (data != null && data.isNotEmpty) {
        response.addAll(data);
      }
      // Unknown DID:
      // - Single DID -> NRC 0x31 (requestOutOfRange)
      // - Multi DID  -> remove the DID bytes we already appended and continue
      else {
        // Remove the DID bytes we appended earlier.
        if (response.length >= 3) {
          response.removeLast();
          response.removeLast();
        }
        if (isSingleDidRequest) {
          return _negativeResponse(0x22, 0x31);
        }
      }
    }

    return Uint8List.fromList(response);
  }

  /// Build minimal FA with VIN only (for when no FA loaded)
  /// Format matches toBinaryVCM() structure for E-Sys compatibility
  Uint8List _buildMinimalFA() {
    final buffer = <int>[];

    // === FA HEADER (matching toBinaryVCM format) ===
    // FA_KENNUNG (1 byte)
    buffer.add(0x03);

    // ENTWICKLUNGS_BAUREIHE (4 bytes)
    buffer.addAll('G030'.codeUnits.take(4));

    // BR_NUMMER (2 bytes) - Type key as number
    buffer.add(0x00);
    buffer.add(0x00);

    // PRODUKTIONSDATUM (3 bytes) - BCD: DD MM YY
    buffer.add(0x15); // 15 (BCD)
    buffer.add(0x03); // March (BCD)
    buffer.add(0x25); // 2025 (BCD)

    // ZEITKRITERIUM (1 byte)
    buffer.add(0x00);

    // LACKCODE (3 bytes)
    buffer.addAll('300'.codeUnits.take(3)); // Default paint

    // POLSTERCODE (4 bytes)
    buffer.addAll('LCSW'.codeUnits.take(4));

    // SA_ANZ (1 byte) + no SAs
    buffer.add(0x00);

    // E_ANZ (1 byte) + no Es
    buffer.add(0x00);

    // HO_ANZ (1 byte) + no HOs
    buffer.add(0x00);

    // Return without length prefix (E-Sys expects raw FA for DID 0x1769)
    return Uint8List.fromList(buffer);
  }

  Uint8List _handleReadMemory(Uint8List request) {
    // Minimal implementation - return zeros
    if (request.length < 4) return _negativeResponse(0x23, 0x13);

    final size = request.length > 6 ? request[6] : 16;
    final response = <int>[0x63];
    response.addAll(List.filled(size, 0x00));

    return Uint8List.fromList(response);
  }

  Uint8List _handleSecurityAccess(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x27, 0x13);

    final subFunc = request[1];

    if (subFunc % 2 == 1) {
      // Request seed (odd subfunction)
      _securityLevel = subFunc;
      // Return a fixed seed for simulation
      return Uint8List.fromList([0x67, subFunc, 0x12, 0x34, 0x56, 0x78]);
    } else {
      // Send key (even subfunction)
      // Accept any key in simulation
      _securityLevel = subFunc;
      return Uint8List.fromList([0x67, subFunc]);
    }
  }

  Uint8List _handleCommunicationControl(Uint8List request) {
    if (request.length < 3) return _negativeResponse(0x28, 0x13);
    return Uint8List.fromList([0x68, request[1]]);
  }

  Uint8List _handleWriteDID(Uint8List request) {
    if (request.length < 4) return _negativeResponse(0x2E, 0x13);

    final did = (request[1] << 8) | request[2];
    final data = request.sublist(3);

    // Store the written data
    _dids[did] = Uint8List.fromList(data);

    return Uint8List.fromList([0x6E, request[1], request[2]]);
  }

  Uint8List _handleIOControl(Uint8List request) {
    if (request.length < 4) return _negativeResponse(0x2F, 0x13);
    return Uint8List.fromList([0x6F, request[1], request[2], request[3]]);
  }

  Uint8List _handleRoutineControl(Uint8List request) {
    if (request.length < 4) return _negativeResponse(0x31, 0x13);

    final subFunc = request[1];
    final routineId = (request[2] << 8) | request[3];
    final routineHi = request[2];
    final routineLo = request[3];
    final routineData = request.length > 4 ? request.sublist(4) : Uint8List(0);

    // Mapping override for this routine.
    final mapped = mapping.handleRoutine(
      this,
      subFunc,
      routineId,
      routineData,
      request,
    );
    if (mapped != null) {
      return mapped;
    }

    debugPrint(
      'VirtualECU[$name]: Routine 0x${routineId.toRadixString(16).padLeft(4, '0')}, SubFunc=0x${subFunc.toRadixString(16).padLeft(2, '0')}',
    );

    switch (routineId) {
      // === 0x0200 - VCM General Status Check ===
      case 0x0200:
        // Return VCM is ready, FA+FP available
        return Uint8List.fromList([
          0x71,
          subFunc,
          routineHi,
          routineLo,
          0x00,
          0x03,
        ]);

      // === 0x0201 - VCM Check Backup Partner ===
      case 0x0201:
        return Uint8List.fromList([
          0x71,
          subFunc,
          routineHi,
          routineLo,
          0x00,
          0x01,
        ]);

      // === 0x0202 - VCM Check Master Partner ===
      case 0x0202:
        return Uint8List.fromList([
          0x71,
          subFunc,
          routineHi,
          routineLo,
          0x00,
          0x01,
        ]);

      // === 0x0203 - Read FA (Fahrzeugauftrag) ===
      case 0x0203:
        if (subFunc == 0x01 || subFunc == 0x03) {
          // Start routine - Return FA data
          Uint8List faBytes;
          if (faData != null) {
            faBytes = faData!.toBinaryVCM();
            debugPrint(
              'VirtualECU[$name]: Routine 0x0203 - FA from faData (${faBytes.length} bytes)',
            );
          } else if (_dids.containsKey(0x3FD0) && _dids[0x3FD0]!.length > 10) {
            faBytes = _dids[0x3FD0]!;
            debugPrint(
              'VirtualECU[$name]: Routine 0x0203 - FA from DID 0x3FD0 (${faBytes.length} bytes)',
            );
          } else {
            faBytes = _buildMinimalFA();
            debugPrint(
              'VirtualECU[$name]: Routine 0x0203 - FA from minimalFA (${faBytes.length} bytes)',
            );
          }
          debugPrint(
            'VirtualECU[$name]: Routine 0x0203 - FA hex: ${faBytes.take(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
          );
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...faBytes,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0204 - Write FA ===
      case 0x0204:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0205 - Read FP (Feature Profile) ===
      case 0x0205:
        if (subFunc == 0x01 || subFunc == 0x03) {
          final fpData = _dids[0xD101] ?? _buildDefaultFP();
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...fpData,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0206 - Read SVT/SVK ===
      case 0x0206:
        if (subFunc == 0x01 || subFunc == 0x03) {
          final svkData = _buildSVK();
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...svkData,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0207 - VCM Read I-Step Shipment ===
      case 0x0207:
        if (subFunc == 0x01 || subFunc == 0x03) {
          final iStepBytes =
              _dids[0x2503] ??
              _dids[0x3F06] ??
              Uint8List.fromList(
                iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
              );
          debugPrint(
            'VirtualECU[$name]: VCM I-Step Shipment: ${iStepBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
          );
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...iStepBytes,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0208 - VCM Read I-Step Current ===
      case 0x0208:
        if (subFunc == 0x01 || subFunc == 0x03) {
          final iStepBytes =
              _dids[0x2504] ??
              _dids[0x100B] ??
              Uint8List.fromList(
                iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
              );
          debugPrint(
            'VirtualECU[$name]: VCM I-Step Current: ${iStepBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
          );
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...iStepBytes,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0209 - VCM Read I-Step Last ===
      case 0x0209:
        if (subFunc == 0x01 || subFunc == 0x03) {
          final iStepBytes =
              _dids[0x2505] ??
              _dids[0x100C] ??
              Uint8List.fromList(
                iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
              );
          debugPrint(
            'VirtualECU[$name]: VCM I-Step Last: ${iStepBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
          );
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...iStepBytes,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x020A - VCM Read Complete Dataset ===
      case 0x020A:
        if (subFunc == 0x01 || subFunc == 0x03) {
          // Return FA + I-Steps combined
          Uint8List faBytes;
          if (faData != null) {
            faBytes = faData!.toBinaryVCM();
          } else if (_dids.containsKey(0x3FD0)) {
            faBytes = _dids[0x3FD0]!;
          } else {
            faBytes = _buildMinimalFA();
          }
          final iStepBytes = Uint8List.fromList(
            iStep.padRight(24, '\x00').codeUnits.take(24).toList(),
          );
          return Uint8List.fromList([
            0x71,
            subFunc,
            routineHi,
            routineLo,
            0x00,
            ...faBytes,
            ...iStepBytes,
          ]);
        }
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0x0F0C - VCM Read Status ===
      case 0x0F0C:
        // VCM Status: 0x00 = OK, FA stored
        return Uint8List.fromList([
          0x71,
          subFunc,
          routineHi,
          routineLo,
          0x00,
          0x01,
        ]);

      // === 0xF000 - Check Programming Preconditions ===
      case 0xF000:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0xF001 - Erase Memory ===
      case 0xF001:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0xF003 - Check Programming Dependencies ===
      case 0xF003:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0xF008 - Check Memory ===
      case 0xF008:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0xF00F - Reset ===
      case 0xF00F:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0xFF00 - Erase Coding ===
      case 0xFF00:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      // === 0xFF01 - Additional Erase ===
      case 0xFF01:
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);

      default:
        // Accept all other routines - positive response
        return Uint8List.fromList([0x71, subFunc, routineHi, routineLo, 0x00]);
    }
  }

  Uint8List _handleRequestDownload(Uint8List request) {
    if (request.length < 4) return _negativeResponse(0x34, 0x13);

    // Accept download request
    return Uint8List.fromList([
      0x74,
      0x20, // Length format
      0x00, 0x00, 0x10, 0x00, // Max block length (4096)
    ]);
  }

  Uint8List _handleRequestUpload(Uint8List request) {
    if (request.length < 4) return _negativeResponse(0x35, 0x13);

    return Uint8List.fromList([0x75, 0x20, 0x00, 0x00, 0x10, 0x00]);
  }

  Uint8List _handleTransferData(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x36, 0x13);

    final blockSeq = request[1];
    return Uint8List.fromList([0x76, blockSeq]);
  }

  Uint8List _handleTransferExit(Uint8List request) {
    return Uint8List.fromList([0x77]);
  }

  Uint8List _handleWriteMemory(Uint8List request) {
    if (request.length < 4) return _negativeResponse(0x3D, 0x13);
    return Uint8List.fromList([0x7D, request[1], request[2]]);
  }

  Uint8List _handleTesterPresent(Uint8List request) {
    final subFunc = request.length > 1 ? request[1] : 0x00;
    _testerPresent = true;

    if (subFunc == 0x80) {
      return Uint8List(0); // Suppress positive response
    }

    return Uint8List.fromList([0x7E, 0x00]);
  }

  Uint8List _handleControlDTCSetting(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x85, 0x13);
    return Uint8List.fromList([0xC5, request[1]]);
  }

  Uint8List _handleKWP2000ReadECUID(Uint8List request) {
    // KWP2000 Read ECU Identification (0x1A) - used by ISTA
    if (request.length < 2) return _negativeResponse(0x1A, 0x13);

    final subFunc = request[1];

    switch (subFunc) {
      // === 0x80 - ECU Identification Scaling Table ===
      case 0x80:
        // Return list of supported sub-functions
        return Uint8List.fromList([
          0x5A,
          subFunc,
          0x81,
          0x82,
          0x85,
          0x86,
          0x8A,
          0x8B,
          0x8C,
          0x90,
        ]);

      // === 0x81, 0x90 - VIN ===
      case 0x81:
      case 0x90:
        return Uint8List.fromList([
          0x5A,
          subFunc,
          ...vin.padRight(17, '\x00').codeUnits.take(17),
        ]);

      // === 0x82 - ECU Hardware Number ===
      case 0x82:
        final hwNum =
            _dids[0xF191] ??
            Uint8List.fromList('8888888'.padRight(20, '\x00').codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...hwNum.take(20)]);

      // === 0x83 - System Supplier ECU Hardware Number ===
      case 0x83:
        final hwNum =
            _dids[0xF193] ??
            Uint8List.fromList('BMW-HW-01'.padRight(20, '\x00').codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...hwNum.take(20)]);

      // === 0x84 - System Supplier ECU Hardware Version ===
      case 0x84:
        final hwVer =
            _dids[0xF194] ??
            Uint8List.fromList('01'.padRight(10, '\x00').codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...hwVer.take(10)]);

      // === 0x85 - ECU Software Number ===
      case 0x85:
        final swNum =
            _dids[0xF188] ??
            Uint8List.fromList(name.padRight(20, '\x00').codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...swNum.take(20)]);

      // === 0x86 - ECU Software Version Number ===
      case 0x86:
        final swVer =
            _dids[0xF189] ??
            Uint8List.fromList('001.001.000'.padRight(20, '\x00').codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...swVer.take(20)]);

      // === 0x87 - Exhaust Regulation or Type Approval Number ===
      case 0x87:
        return Uint8List.fromList([
          0x5A,
          subFunc,
          ...'EU6D-TEMP'.padRight(20, '\x00').codeUnits.take(20),
        ]);

      // === 0x88 - System Name or Engine Type ===
      case 0x88:
        return Uint8List.fromList([
          0x5A,
          subFunc,
          ...name.padRight(20, '\x00').codeUnits.take(20),
        ]);

      // === 0x89 - Repair Shop Code ===
      case 0x89:
        return Uint8List.fromList([
          0x5A,
          subFunc,
          ...'BMW-SIM'.padRight(10).codeUnits.take(10),
        ]);

      // === 0x8A - Programming Date ===
      case 0x8A:
        final progDate =
            _dids[0xF199] ?? Uint8List.fromList('2025/03/28'.codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...progDate.take(10)]);

      // === 0x8B, 0x9B - ECU Manufacturing Date ===
      case 0x8B:
      case 0x9B:
        final mfgDate =
            _dids[0xF18B] ?? Uint8List.fromList('2024/01/15'.codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...mfgDate.take(10)]);

      // === 0x8C - ECU Serial Number ===
      case 0x8C:
        final serial =
            _dids[0xF18C] ??
            Uint8List.fromList('1234567890'.padRight(20).codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...serial.take(20)]);

      // === 0x9A - System Supplier Identifier ===
      case 0x9A:
        final supplier =
            _dids[0xF18A] ?? Uint8List.fromList('BMW'.padRight(20).codeUnits);
        return Uint8List.fromList([0x5A, subFunc, ...supplier.take(20)]);

      default:
        // Sub-function not supported
        return _negativeResponse(0x1A, 0x12);
    }
  }

  Uint8List _negativeResponse(int serviceId, int nrc) {
    return Uint8List.fromList([0x7F, serviceId, nrc]);
  }

  /// NRC codes
  static const int nrcGeneralReject = 0x10;
  static const int nrcServiceNotSupported = 0x11;
  static const int nrcSubFunctionNotSupported = 0x12;
  static const int nrcIncorrectMessageLength = 0x13;
  static const int nrcConditionsNotCorrect = 0x22;
  static const int nrcRequestSequenceError = 0x24;
  static const int nrcRequestOutOfRange = 0x31;
  static const int nrcSecurityAccessDenied = 0x33;
  static const int nrcInvalidKey = 0x35;
  static const int nrcExceedNumberOfAttempts = 0x36;
  static const int nrcTransferDataSuspended = 0x71;
  static const int nrcGeneralProgrammingFailure = 0x72;
  static const int nrcServiceNotSupportedInActiveSession = 0x7F;

  /// Handle OBD-II Mode 01 - Current Powertrain Data
  /// Based on all_data.txt log analysis - Real BMW NBT EVO responses
  /// Log format: 010C -> 010C0000 (raw format without 41 prefix from BMW gateway)
  Uint8List _handleOBDMode01(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x01, 0x13);

    final pid = request[1];

    // Response: 41 [PID] [Data...]
    // From all_data.txt: BMW returns raw format 01XX0000 or 41XX00
    switch (pid) {
      case 0x00: // Supported PIDs 01-20
        // Bitmap showing which PIDs are supported
        return Uint8List.fromList([0x41, 0x00, 0xBE, 0x1F, 0xB8, 0x13]);

      case 0x01: // Monitor status since DTCs cleared
        return Uint8List.fromList([0x41, 0x01, 0x00, 0x07, 0xE5, 0x00]);

      case 0x04: // Calculated engine load (0-100%)
        // From log: 01040000 -> 0%
        return Uint8List.fromList([0x41, 0x04, 0x00]);

      case 0x05: // Engine coolant temperature (-40 to 215C)
        // From log: 410562 -> 98-40=58C
        return Uint8List.fromList([0x41, 0x05, 0x62]);

      case 0x0C: // Engine RPM (0-16383.75)
        // From log: 010C0000 -> 0 RPM (engine off)
        // RPM = ((A*256)+B)/4
        return Uint8List.fromList([0x41, 0x0C, 0x00, 0x00]);

      case 0x0D: // Vehicle speed (0-255 km/h)
        // From log: 010D0000 -> 0 km/h
        return Uint8List.fromList([0x41, 0x0D, 0x00]);

      case 0x0F: // Intake air temperature (-40 to 215C)
        // From log: 010F0000 -> -40C (min value)
        return Uint8List.fromList([0x41, 0x0F, 0x28]); // 0C

      case 0x10: // MAF air flow rate
        return Uint8List.fromList([0x41, 0x10, 0x00, 0x00]);

      case 0x11: // Throttle position (0-100%)
        // From log: 01110000 -> 0%
        return Uint8List.fromList([0x41, 0x11, 0x00]);

      case 0x12: // Commanded secondary air status
        return Uint8List.fromList([0x41, 0x12, 0x00]);

      case 0x1C: // OBD standards compliance
        return Uint8List.fromList([0x41, 0x1C, 0x06]); // EOBD

      case 0x1F: // Run time since engine start
        return Uint8List.fromList([0x41, 0x1F, 0x00, 0x00]);

      case 0x20: // Supported PIDs 21-40
        return Uint8List.fromList([0x41, 0x20, 0x80, 0x01, 0x80, 0x01]);

      case 0x21: // Distance traveled with MIL on
        return Uint8List.fromList([0x41, 0x21, 0x00, 0x00]);

      case 0x2F: // Fuel tank level (0-100%)
        // From log: 012F0000 -> 0%
        return Uint8List.fromList([0x41, 0x2F, 0x50]); // ~31%

      case 0x30: // Warm-ups since codes cleared
        return Uint8List.fromList([0x41, 0x30, 0x00]);

      case 0x31: // Distance traveled since codes cleared
        return Uint8List.fromList([0x41, 0x31, 0x00, 0x00]);

      case 0x33: // Barometric pressure
        return Uint8List.fromList([0x41, 0x33, 0x65]); // 101 kPa

      case 0x40: // Supported PIDs 41-60
        return Uint8List.fromList([0x41, 0x40, 0x6C, 0x00, 0x80, 0x01]);

      case 0x42: // Control module voltage
        return Uint8List.fromList([0x41, 0x42, 0x37, 0x98]); // ~14.2V

      case 0x46: // Ambient air temperature (-40 to 215C)
        // From log: 01460000 -> -40C
        return Uint8List.fromList([0x41, 0x46, 0x3C]); // 20C

      case 0x49: // Accelerator pedal position D
        return Uint8List.fromList([0x41, 0x49, 0x00]);

      case 0x4A: // Accelerator pedal position E
        return Uint8List.fromList([0x41, 0x4A, 0x00]);

      case 0x4C: // Commanded throttle actuator
        return Uint8List.fromList([0x41, 0x4C, 0x00]);

      case 0x51: // Fuel type
        return Uint8List.fromList([0x41, 0x51, 0x01]); // Gasoline

      case 0x5C: // Oil temperature (-40 to 210C)
        // From log: 015C0000 -> -40C
        return Uint8List.fromList([0x41, 0x5C, 0x50]); // 40C

      case 0x60: // Supported PIDs 61-80
        return Uint8List.fromList([0x41, 0x60, 0x00, 0x00, 0x00, 0x01]);

      case 0x80: // Supported PIDs 81-A0
        return Uint8List.fromList([0x41, 0x80, 0x00, 0x00, 0x00, 0x00]);

      default:
        // Unknown PID - return with zeros like in log
        // Format: 41 [PID] 00 00
        return Uint8List.fromList([0x41, pid, 0x00, 0x00]);
    }
  }

  /// Handle OBD-II Mode 03 - Read DTCs
  Uint8List _handleOBDMode03(Uint8List request) {
    if (_activeDTCs.isEmpty) {
      // No DTCs - return count = 0
      return Uint8List.fromList([0x43, 0x00]);
    }

    final response = <int>[0x43, _activeDTCs.length.clamp(0, 255)];
    for (var dtc in _activeDTCs.take(126)) {
      // Each DTC is 2 bytes
      response.add((dtc >> 8) & 0xFF);
      response.add(dtc & 0xFF);
    }
    return Uint8List.fromList(response);
  }

  /// Handle OBD-II Mode 04 - Clear DTCs
  Uint8List _handleOBDMode04(Uint8List request) {
    _activeDTCs.clear();
    return Uint8List.fromList([0x44]);
  }

  /// Handle OBD-II Mode 09 - Vehicle Information
  Uint8List _handleOBDMode09(Uint8List request) {
    if (request.length < 2) return _negativeResponse(0x09, 0x13);

    final infotype = request[1];

    switch (infotype) {
      case 0x00: // Supported PIDs
        return Uint8List.fromList([0x49, 0x00, 0x01, 0x55, 0x40, 0x00, 0x00]);

      case 0x02: // VIN
        final vinBytes = vin.padRight(17, '\x00').codeUnits.take(17).toList();
        final response = <int>[0x49, 0x02, 0x01];
        response.addAll(vinBytes);
        return Uint8List.fromList(response);

      case 0x04: // Calibration ID
        return Uint8List.fromList([
          0x49,
          0x04,
          0x01,
          ...'BMW_CAL_001'.padRight(16, '\x00').codeUnits.take(16),
        ]);

      case 0x06: // CVN
        return Uint8List.fromList([0x49, 0x06, 0x01, 0x00, 0x00, 0x00, 0x00]);

      case 0x0A: // ECU name
        return Uint8List.fromList([
          0x49,
          0x0A,
          0x01,
          ...name.padRight(20, '\x00').codeUnits.take(20),
        ]);

      default:
        return Uint8List.fromList([0x49, infotype, 0x00]);
    }
  }
}
