class BreakdownRecord {
  BreakdownRecord({required this.id, required this.date, required this.note});

  final String id;
  final DateTime date;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory BreakdownRecord.fromJson(Map<String, dynamic> json) {
    return BreakdownRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String,
    );
  }
}
