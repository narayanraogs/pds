class CriticalParameter {
  final String id;
  final String mnemonic;
  final double lowerLimit;
  final double upperLimit;
  final double maxChangeThreshold;
  final bool isActive;

  CriticalParameter({
    required this.id,
    required this.mnemonic,
    required this.lowerLimit,
    required this.upperLimit,
    this.maxChangeThreshold = 0.0,
    this.isActive = true,
  });

  factory CriticalParameter.fromJson(Map<String, dynamic> json) {
    return CriticalParameter(
      id: json['id'] ?? '',
      mnemonic: json['mnemonic'] ?? '',
      lowerLimit: (json['lower_limit'] as num?)?.toDouble() ?? 0.0,
      upperLimit: (json['upper_limit'] as num?)?.toDouble() ?? 0.0,
      maxChangeThreshold: (json['max_change_threshold'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] == null ? true : (json['is_active'] == true || json['is_active'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mnemonic': mnemonic,
      'lower_limit': lowerLimit,
      'upper_limit': upperLimit,
      'max_change_threshold': maxChangeThreshold,
      'is_active': isActive,
    };
  }

  CriticalParameter copyWith({
    String? id,
    String? mnemonic,
    double? lowerLimit,
    double? upperLimit,
    double? maxChangeThreshold,
    bool? isActive,
  }) {
    return CriticalParameter(
      id: id ?? this.id,
      mnemonic: mnemonic ?? this.mnemonic,
      lowerLimit: lowerLimit ?? this.lowerLimit,
      upperLimit: upperLimit ?? this.upperLimit,
      maxChangeThreshold: maxChangeThreshold ?? this.maxChangeThreshold,
      isActive: isActive ?? this.isActive,
    );
  }
}
