class CountryModel {
  const CountryModel({
    required this.name,
    required this.code,
    required this.flag,
  });

  final String name;

  final String code;

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
