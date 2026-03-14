class CountryModel {
  const CountryModel({
    required this.name,
    required this.code,
    required this.flag,
  });

  /// Common name (e.g. "Philippines")
  final String name;

  /// ISO 3166-1 alpha-2 code (e.g. "PH")
  final String code;

  /// Unicode flag emoji (e.g. "🇵🇭")
  final String flag;

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    final nameObj = json['name'] as Map<String, dynamic>?;
    return CountryModel(
      name: (nameObj?['common'] as String?) ?? '',
      code: (json['cca2'] as String?) ?? '',
      flag: (json['flag'] as String?) ?? '',
    );
  }

  @override
  String toString() => name;
}
