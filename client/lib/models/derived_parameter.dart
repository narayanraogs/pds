class DerivedParameter {
  final String id;
  final String mnemonic;
  final String unit;
  final String expression;

  DerivedParameter({
    required this.id,
    required this.mnemonic,
    required this.unit,
    required this.expression,
  });

  factory DerivedParameter.fromJson(Map<String, dynamic> json) {
    return DerivedParameter(
      id: json['id'] as String,
      mnemonic: json['mnemonic'] as String,
      unit: json['unit'] as String,
      expression: json['expression'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mnemonic': mnemonic,
      'unit': unit,
      'expression': expression,
    };
  }
}
