class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.text,
    required this.manualWins,
    required this.smartHighlights,
  });

  final String id;
  final DateTime date;
  final String text;
  final List<String> manualWins;
  final List<String> smartHighlights;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'text': text,
    'manualWins': manualWins,
    'smartHighlights': smartHighlights,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
      manualWins: (json['manualWins'] as List<dynamic>).cast<String>(),
      smartHighlights: (json['smartHighlights'] as List<dynamic>).cast<String>(),
    );
  }
}
