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
    this.audioPaths = const <String>[],
    this.audioDurationMsList = const <int>[],
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
  final List<String> audioPaths;
  final List<int> audioDurationMsList;
  final String? transcript;

  List<String> get resolvedAudioPaths {
    final items = <String>[];
    for (final path in audioPaths) {
      final trimmed = path.trim();
      if (trimmed.isNotEmpty && !items.contains(trimmed)) {
        items.add(trimmed);
      }
    }
    final legacy = audioPath?.trim();
    if (legacy != null && legacy.isNotEmpty && !items.contains(legacy)) {
      items.add(legacy);
    }
    return items;
  }

  List<int> get resolvedAudioDurations {
    if (audioDurationMsList.isNotEmpty) {
      return [...audioDurationMsList];
    }
    if (audioDurationMs != null) {
      return [audioDurationMs!];
    }
    return const <int>[];
  }

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
    List<String>? audioPaths,
    List<int>? audioDurationMsList,
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
      audioPaths: audioPaths ?? this.audioPaths,
      audioDurationMsList: audioDurationMsList ?? this.audioDurationMsList,
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
    'audioPath': audioPath ?? (resolvedAudioPaths.isEmpty ? null : resolvedAudioPaths.first),
    'audioDurationMs':
        audioDurationMs ?? (resolvedAudioDurations.isEmpty ? null : resolvedAudioDurations.first),
    'audioPaths': resolvedAudioPaths,
    'audioDurationMsList': resolvedAudioDurations,
    'transcript': transcript,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final parsedAudioPaths =
        ((json['audioPaths'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();

    final parsedAudioDurations =
        ((json['audioDurationMsList'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) {
              if (item is int) {
                return item;
              }
              if (item is num) {
                return item.toInt();
              }
              return int.tryParse(item.toString());
            })
            .whereType<int>()
            .toList();

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
      audioPath: (json['audioPath'] as String?)?.trim().isEmpty == true
          ? null
          : json['audioPath'] as String?,
      audioDurationMs: json['audioDurationMs'] as int?,
      audioPaths: parsedAudioPaths,
      audioDurationMsList: parsedAudioDurations,
      transcript: json['transcript'] as String?,
    );
  }
}
