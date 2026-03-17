import '../models/breakdown_record.dart';
import '../models/journal_entry.dart';

abstract class ExtractionService {
  Future<List<String>> extractJournalWins({
    required String journalText,
    required List<String> manualWins,
  });

  Future<List<String>> summarizeBreakdownWindow({
    required BreakdownRecord selectedBreakdown,
    required DateTime? previousBreakdownDate,
    required List<JournalEntry> windowEntries,
    required int maxHighlights,
  });
}

class LocalExtractionService implements ExtractionService {
  static final RegExp _sentenceSplit = RegExp(r'[.!?\n]+');
  static final List<String> _strongSignals = [
    'completed',
    'finished',
    'achieved',
    'built',
    'submitted',
    'helped',
    'improved',
    'solved',
    'learned',
    'shipped',
    'won',
    'organized',
    'created',
    'managed to',
    'able to',
    'done',
  ];

  static final List<String> _negativeSignals = [
    'failed',
    'panic',
    'anxious',
    'sad',
    'overwhelmed',
    'could not',
    'did not',
    'stuck',
  ];

  @override
  Future<List<String>> extractJournalWins({
    required String journalText,
    required List<String> manualWins,
  }) async {
    if (manualWins.isNotEmpty) {
      return manualWins.map(_normalize).where((e) => e.isNotEmpty).toList();
    }

    final candidates = journalText
        .split(_sentenceSplit)
        .map((s) => s.trim())
        .where((s) => s.length > 12)
        .toList();

    final scored = <MapEntry<String, int>>[];
    for (final sentence in candidates) {
      final lower = sentence.toLowerCase();
      var score = 0;

      for (final signal in _strongSignals) {
        if (lower.contains(signal)) {
          score += 2;
        }
      }
      for (final signal in _negativeSignals) {
        if (lower.contains(signal)) {
          score -= 2;
        }
      }
      if (RegExp(r'\b(today|finally|progress|milestone)\b').hasMatch(lower)) {
        score += 1;
      }
      if (sentence.split(' ').length >= 6) {
        score += 1;
      }

      if (score >= 3) {
        scored.add(MapEntry(_normalize(sentence), score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).take(4).toList();
  }

  @override
  Future<List<String>> summarizeBreakdownWindow({
    required BreakdownRecord selectedBreakdown,
    required DateTime? previousBreakdownDate,
    required List<JournalEntry> windowEntries,
    required int maxHighlights,
  }) async {
    final merged = <String>[];
    for (final entry in windowEntries) {
      if (entry.manualWins.isNotEmpty) {
        merged.addAll(entry.manualWins);
      } else {
        merged.addAll(await extractJournalWins(journalText: entry.text, manualWins: []));
      }
    }

    final unique = <String>{};
    for (final item in merged) {
      unique.add(_normalize(item));
    }

    return unique.where((item) => item.isNotEmpty).take(maxHighlights).toList();
  }

  String _normalize(String input) {
    final clean = input.trim();
    if (clean.isEmpty) {
      return '';
    }
    return clean[0].toUpperCase() + clean.substring(1);
  }
}
