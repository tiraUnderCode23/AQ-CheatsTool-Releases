/// ECU Model - Represents a vehicle ECU
class ECU {
  final String name;
  final String variant;
  final int address;
  final List<ECUFile> files;
  final Map<String, dynamic> properties;

  ECU({
    required this.name,
    required this.variant,
    required this.address,
    this.files = const [],
    this.properties = const {},
  });

  String get addressHex =>
      '0x${address.toRadixString(16).toUpperCase().padLeft(2, '0')}';

  ECU copyWith({
    String? name,
    String? variant,
    int? address,
    List<ECUFile>? files,
    Map<String, dynamic>? properties,
  }) {
    return ECU(
      name: name ?? this.name,
      variant: variant ?? this.variant,
      address: address ?? this.address,
      files: files ?? this.files,
      properties: properties ?? this.properties,
    );
  }

  factory ECU.fromXml(Map<String, dynamic> xml) {
    return ECU(
      name: xml['name'] ?? 'Unknown',
      variant: xml['baseVariant'] ?? xml['variant'] ?? '',
      address: _parseAddress(xml['diagAddress'] ?? xml['address'] ?? '0'),
      properties: xml,
    );
  }

  static int _parseAddress(String addr) {
    try {
      if (addr.startsWith('0x') || addr.startsWith('0X')) {
        return int.parse(addr.substring(2), radix: 16);
      }
      return int.tryParse(addr, radix: 16) ?? int.tryParse(addr) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'variant': variant,
    'address': address,
    'files': files.map((f) => f.toJson()).toList(),
    'properties': properties,
  };
}

/// ECU File - Represents a software file (BTLD, SWFL, CAFD, etc.)
class ECUFile {
  final String processClass; // BTLD, SWFL, SWFK, CAFD, IBAD, etc.
  final String id;
  final String mainVersion;
  final String subVersion;
  final String patchVersion;
  final String? path;
  final FileStatus status;

  ECUFile({
    required this.processClass,
    required this.id,
    required this.mainVersion,
    required this.subVersion,
    required this.patchVersion,
    this.path,
    this.status = FileStatus.unknown,
  });

  String get version => '$mainVersion.$subVersion.$patchVersion';

  String get sgbmId =>
      '${processClass}_${id}_${mainVersion.padLeft(3, '0')}_${subVersion.padLeft(3, '0')}_${patchVersion.padLeft(3, '0')}';

  String get searchPattern =>
      '${processClass.toLowerCase()}_${id.toLowerCase()}';

  ECUFile copyWith({
    String? processClass,
    String? id,
    String? mainVersion,
    String? subVersion,
    String? patchVersion,
    String? path,
    FileStatus? status,
  }) {
    return ECUFile(
      processClass: processClass ?? this.processClass,
      id: id ?? this.id,
      mainVersion: mainVersion ?? this.mainVersion,
      subVersion: subVersion ?? this.subVersion,
      patchVersion: patchVersion ?? this.patchVersion,
      path: path ?? this.path,
      status: status ?? this.status,
    );
  }

  factory ECUFile.fromSgbmId(Map<String, dynamic> data) {
    return ECUFile(
      processClass: data['processClass'] ?? data['class'] ?? 'SWFL',
      id: data['id'] ?? '',
      mainVersion: data['mainVersion'] ?? data['main'] ?? '000',
      subVersion: data['subVersion'] ?? data['sub'] ?? '000',
      patchVersion: data['patchVersion'] ?? data['patch'] ?? '000',
      path: data['path'],
      status: FileStatus.unknown,
    );
  }

  Map<String, dynamic> toJson() => {
    'processClass': processClass,
    'id': id,
    'mainVersion': mainVersion,
    'subVersion': subVersion,
    'patchVersion': patchVersion,
    'path': path,
    'status': status.name,
  };
}

enum FileStatus { unknown, found, missing, versionMismatch }
