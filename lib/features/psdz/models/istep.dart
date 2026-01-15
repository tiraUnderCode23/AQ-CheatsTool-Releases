/// I-Step Model - Represents a vehicle software integration level
class IStep {
  final String name;
  final String series;
  final String path;
  final int ecuCount;
  final int fileCount;
  final int sizeBytes;

  IStep({
    required this.name,
    required this.series,
    required this.path,
    this.ecuCount = 0,
    this.fileCount = 0,
    this.sizeBytes = 0,
  });

  String get displayName => name;

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IStep copyWith({
    String? name,
    String? series,
    String? path,
    int? ecuCount,
    int? fileCount,
    int? sizeBytes,
  }) {
    return IStep(
      name: name ?? this.name,
      series: series ?? this.series,
      path: path ?? this.path,
      ecuCount: ecuCount ?? this.ecuCount,
      fileCount: fileCount ?? this.fileCount,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'series': series,
    'path': path,
    'ecuCount': ecuCount,
    'fileCount': fileCount,
    'sizeBytes': sizeBytes,
  };
}

/// Series Model - Represents a vehicle series (G30, F10, etc.)
class VehicleSeries {
  final String code;
  final String? description;
  final List<IStep> iSteps;
  final int totalSize;

  VehicleSeries({
    required this.code,
    this.description,
    this.iSteps = const [],
    this.totalSize = 0,
  });

  String get displayName => description != null ? '$code - $description' : code;

  String get sizeFormatted {
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  VehicleSeries copyWith({
    String? code,
    String? description,
    List<IStep>? iSteps,
    int? totalSize,
  }) {
    return VehicleSeries(
      code: code ?? this.code,
      description: description ?? this.description,
      iSteps: iSteps ?? this.iSteps,
      totalSize: totalSize ?? this.totalSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'description': description,
    'iSteps': iSteps.map((i) => i.toJson()).toList(),
    'totalSize': totalSize,
  };
}
