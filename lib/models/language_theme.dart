class LanguageTheme {
  final String id;
  final String name;
  final String languageTypeId;   // matches 'language_type_id' in DB
  final int position;

  LanguageTheme({
    required this.id,
    required this.name,
    required this.languageTypeId,
    this.position = 0,
  });

  factory LanguageTheme.fromSupabase(Map<String, dynamic> map) {
    return LanguageTheme(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      languageTypeId: map['language_type_id'] ?? '',
      position: map['position'] ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'name': name,
      'language_type_id': languageTypeId,
      'position': position,
    };
  }
}