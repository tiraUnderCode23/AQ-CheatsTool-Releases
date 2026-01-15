import 'ecu.dart';

/// TAL/SVT File Model - Represents a TAL or SVT XML file
class TALFile {
  final String path;
  final String filename;
  final TALFileType type;
  final String? vin;
  final String? series;
  final String? iStep;
  final List<ECU> ecus;
  final DateTime? lastModified;
  final bool isModified;
  final String? _originalContent;

  TALFile({
    required this.path,
    required this.filename,
    required this.type,
    this.vin,
    this.series,
    this.iStep,
    this.ecus = const [],
    this.lastModified,
    this.isModified = false,
    String? originalContent,
  }) : _originalContent = originalContent;

  String? get originalContent => _originalContent;
  int get ecuCount => ecus.length;
  int get totalFileCount => ecus.fold(0, (sum, ecu) => sum + ecu.files.length);

  TALFile copyWith({
    String? path,
    String? filename,
    TALFileType? type,
    String? vin,
    String? series,
    String? iStep,
    List<ECU>? ecus,
    DateTime? lastModified,
    bool? isModified,
    String? originalContent,
  }) {
    return TALFile(
      path: path ?? this.path,
      filename: filename ?? this.filename,
      type: type ?? this.type,
      vin: vin ?? this.vin,
      series: series ?? this.series,
      iStep: iStep ?? this.iStep,
      ecus: ecus ?? this.ecus,
      lastModified: lastModified ?? this.lastModified,
      isModified: isModified ?? this.isModified,
      originalContent: originalContent ?? _originalContent,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'filename': filename,
    'type': type.name,
    'vin': vin,
    'series': series,
    'iStep': iStep,
    'ecus': ecus.map((e) => e.toJson()).toList(),
    'lastModified': lastModified?.toIso8601String(),
    'isModified': isModified,
  };
}

enum TALFileType { tal, svt, fa, unknown }

/// TAL Line Model - Represents a single TAL line action
class TALLine {
  final String baseVariant;
  final int diagAddress;
  final TALAction action;
  final List<ECUFile> files;

  TALLine({
    required this.baseVariant,
    required this.diagAddress,
    required this.action,
    this.files = const [],
  });

  String get addressHex => '0x' + diagAddress.toRadixString(16).toUpperCase().padLeft(2, '0');

  TALLine copyWith({
    String? baseVariant,
    int? diagAddress,
    TALAction? action,
    List<ECUFile>? files,
  }) {
    return TALLine(
      baseVariant: baseVariant ?? this.baseVariant,
      diagAddress: diagAddress ?? this.diagAddress,
      action: action ?? this.action,
      files: files ?? this.files,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseVariant': baseVariant,
    'diagAddress': diagAddress,
    'action': action.name,
    'files': files.map((f) => f.toJson()).toList(),
  };
}

enum TALAction { blFlash, swDeploy, cdDeploy, ibaDeploy, hwDeinstall, unknown }

/// Library scan result
class LibraryScanResult {
  final String path;
  final String filename;
  final TALFileType type;
  final String? vin;
  final String? series;
  final int ecuCount;

  LibraryScanResult({
    required this.path,
    required this.filename,
    required this.type,
    this.vin,
    this.series,
    this.ecuCount = 0,
  });
}

/// Vehicle File - Represents FA, SVT, or TAL file from C:/data
class VehicleFile {
  final String path;
  final String filename;
  final String type; // 'FA', 'SVT', 'TAL'
  final String? vin;
  final String? series;
  final String? istep;
  final int ecuCount;
  final DateTime? lastModified;

  VehicleFile({
    required this.path,
    required this.filename,
    required this.type,
    this.vin,
    this.series,
    this.istep,
    this.ecuCount = 0,
    this.lastModified,
  });

  String get vinShort {
    if (vin != null && vin!.length >= 7) {
      return vin!.substring(vin!.length - 7);
    }
    return vin ?? 'Unknown';
  }

  String get displayName {
    if (vin != null) {
      return vin! + ' (' + (series ?? 'Unknown') + ')';
    }
    return filename;
  }
}

/// Matched Vehicle - FA and SVT with same VIN
class MatchedVehicle {
  final String vin;
  final VehicleFile? faFile;
  final VehicleFile? svtFile;
  final List<VehicleFile> talFiles;
  final String? series;
  final String? istep;

  MatchedVehicle({
    required this.vin,
    this.faFile,
    this.svtFile,
    this.talFiles = const [],
    this.series,
    this.istep,
  });

  bool get hasFA => faFile != null;
  bool get hasSVT => svtFile != null;
  bool get hasTAL => talFiles.isNotEmpty;
  bool get isComplete => hasFA && hasSVT;

  String get vinShort {
    if (vin.length >= 7) {
      return vin.substring(vin.length - 7);
    }
    return vin;
  }

  String get displayName {
    return vinShort + ' (' + (series ?? 'Unknown') + ')';
  }

  int get fileCount {
    int count = 0;
    if (hasFA) count++;
    if (hasSVT) count++;
    count += talFiles.length;
    return count;
  }
}
