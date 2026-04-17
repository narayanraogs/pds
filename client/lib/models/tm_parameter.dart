import 'package:flutter/material.dart';

enum TMStatus {
  normal,
  nearUpper,
  crossedUpper,
  nearLower,
  crossedLower,
}

class TMParameter {
  final String mnemonic;
  final String units;
  final String tm1Value;
  final String tm2Value;
  final double upperLimit;
  final double lowerLimit;
  final double tolerance;
  final List<double> tm1History;
  final List<double> tm2History;

  TMParameter({
    required this.mnemonic,
    this.units = '',
    this.tm1Value = '',
    this.tm2Value = '',
    this.upperLimit = 0.0,
    this.lowerLimit = 0.0,
    this.tolerance = 0.0,
    this.tm1History = const [],
    this.tm2History = const [],
  });

  // Calculate status based on current values and limits
  TMStatus get status1 => _calculateStatus(tm1Value);
  TMStatus get status2 => _calculateStatus(tm2Value);

  TMStatus _calculateStatus(String valueStr) {
    if (valueStr.isEmpty || valueStr == "---") return TMStatus.normal;
    final value = double.tryParse(valueStr);
    if (value == null) return TMStatus.normal;

    if (value >= upperLimit && upperLimit != 0) return TMStatus.crossedUpper;
    if (value <= lowerLimit && lowerLimit != 0) return TMStatus.crossedLower;
    
    // Nearing: within tolerance of the limits
    if (tolerance > 0) {
        if (value >= (upperLimit - tolerance)) return TMStatus.nearUpper;
        if (value <= (lowerLimit + tolerance)) return TMStatus.nearLower;
    }
    
    return TMStatus.normal;
  }

  static Color getStatusColor(TMStatus status) {
    switch (status) {
      case TMStatus.normal:
        return Colors.green.shade400;
      case TMStatus.nearUpper:
      case TMStatus.nearLower:
        return Colors.orange.shade400;
      case TMStatus.crossedUpper:
      case TMStatus.crossedLower:
        return Colors.red.shade400;
    }
  }

  // UPDATED to match lowercase Go tags
  factory TMParameter.fromJson(Map<String, dynamic> json) {
    return TMParameter(
      mnemonic: json['mnemonic'] ?? '',
      units: json['units'] ?? '',
      tm1Value: json['tm1_value'] ?? '',
      tm2Value: json['tm2_value'] ?? '',
      upperLimit: (json['upper_limit'] as num?)?.toDouble() ?? 0.0,
      lowerLimit: (json['lower_limit'] as num?)?.toDouble() ?? 0.0,
      tolerance: (json['tolerance'] as num?)?.toDouble() ?? 0.0,
      tm1History: const [], // History is managed locally in the provider
      tm2History: const [], 
    );
  }

  TMParameter copyWith({
    String? tm1Value,
    String? tm2Value,
    List<double>? tm1History,
    List<double>? tm2History,
  }) {
    return TMParameter(
      mnemonic: mnemonic,
      units: units,
      tm1Value: tm1Value ?? this.tm1Value,
      tm2Value: tm2Value ?? this.tm2Value,
      upperLimit: upperLimit,
      lowerLimit: lowerLimit,
      tolerance: tolerance,
      tm1History: tm1History ?? this.tm1History,
      tm2History: tm2History ?? this.tm2History,
    );
  }
}
