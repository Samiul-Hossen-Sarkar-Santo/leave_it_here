class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.text,
    required this.manualWins,
    required this.smartHighlights,
    required this.isBreakdownEntry,
    required this.isPermanentlyLocked,
    this.breakdownRecordId,
    this.audioPath,
    this.audioDurationMs,
    this.transcript,
  });

  final String id;
  final DateTime date;
  final String text;
  final List<String> manualWins;
  final List<String> smartHighlights;
  final bool isBreakdownEntry;
  final bool isPermanentlyLocked;
  final String? breakdownRecordId;
  final String? audioPath;
  final int? audioDurationMs;
  final String? transcript;

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? text,
    List<String>? manualWins,
    List<String>? smartHighlights,
    bool? isBreakdownEntry,
    bool? isPermanentlyLocked,
    String? breakdownRecordId,
    String? audioPath,
    int? audioDurationMs,
    String? transcript,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      text: text ?? this.text,
      manualWins: manualWins ?? this.manualWins,
      smartHighlights: smartHighlights ?? this.smartHighlights,
      isBreakdownEntry: isBreakdownEntry ?? this.isBreakdownEntry,
      isPermanentlyLocked: isPermanentlyLocked ?? this.isPermanentlyLocked,
      breakdownRecordId: breakdownRecordId ?? this.breakdownRecordId,
      audioPath: audioPath ?? this.audioPath,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      transcript: transcript ?? this.transcript,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'text': text,
    'manualWins': manualWins,
    'smartHighlights': smartHighlights,
    'isBreakdownEntry': isBreakdownEntry,
    'isPermanentlyLocked': isPermanentlyLocked,
    'breakdownRecordId': breakdownRecordId,
    'audioPath': audioPath,
    'audioDurationMs': audioDurationMs,
    'transcript': transcript,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
      manualWins: ((json['manualWins'] as List<dynamic>?) ?? []).cast<String>(),
      smartHighlights:
          ((json['smartHighlights'] as List<dynamic>?) ?? []).cast<String>(),
      isBreakdownEntry: json['isBreakdownEntry'] as bool? ?? false,
      isPermanentlyLocked: json['isPermanentlyLocked'] as bool? ?? false,
      breakdownRecordId: json['breakdownRecordId'] as String?,
      audioPath: json['audioPath'] as String?,
      audioDurationMs: json['audioDurationMs'] as int?,
      transcript: json['transcript'] as String?,
    );
  }
}
