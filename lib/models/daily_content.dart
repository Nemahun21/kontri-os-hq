class DailyContent {
  final String id;
  final String type; 
  final String text;
  final String? meaning;
  final String? imageUrl;
  final int position;

  DailyContent({
    required this.id,
    required this.type,
    required this.text,
    this.meaning,
    this.imageUrl,
    this.position = 0,
  });

  factory DailyContent.fromSupabase(Map<String, dynamic> json) => DailyContent(
    id: json['id'],
    type: json['type'],
    text: json['text'],
    meaning: json['meaning'],
    imageUrl: json['image_url'],
    position: json['position'] ?? 0,
  );

  Map<String, dynamic> toSupabase() => {
    'id': id,
    'type': type,
    'text': text,
    'meaning': meaning,
    'image_url': imageUrl,
    'position': position,
  };
}