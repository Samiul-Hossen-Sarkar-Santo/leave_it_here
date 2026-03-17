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

class HeuristicExtractionService implements ExtractionService {
  static final RegExp _sentenceSplit = RegExp(r'[.!?\n]+');
  static final RegExp _bulletPrefix = RegExp(r'^[-•*\d.)\s]+');

  static const List<String> _strongSignals = [
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
    'followed through',
    'delivered',
    'fixed',
    'handled',
    'showed up',
    'kept going',
  ];

  static const List<String> _progressSignals = [
    'today',
    'finally',
    'progress',
    'milestone',
    'step forward',
    'on track',
    'consistent',
    'streak',
    'finished up',
    'moved forward',
  ];

  static const List<String> _effortSignals = [
    'i tried',
    'i showed up',
    'i reached out',
    'i asked for help',
    'i rested',
    'i took a break',
    'i kept going',
    'i did it anyway',
    'despite',
    'even though',
  ];

  static const List<String> _negativeSignals = [
    'failed',
    'panic',
    'anxious',
    'sad',
    'overwhelmed',
    'could not',
    'did not',
    'stuck',
    'worthless',
    'hopeless',
  ];

  @override
  Future<List<String>> extractJournalWins({
    required String journalText,
    required List<String> manualWins,
  }) async {
    final cleanedManual = _normalizeAndDedupe(manualWins);
    if (cleanedManual.isNotEmpty) {
      return cleanedManual;
    }

    final candidates = _extractScoredSentences(journalText);
    return candidates.map((entry) => entry.key).toList();
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
        continue;
      }

      final extracted = _extractScoredSentences(entry.text)
          .map((entry) => entry.key)
          .take(maxHighlights)
          .toList();
      merged.addAll(extracted);
    }

    return _normalizeAndDedupe(merged).take(maxHighlights).toList();
  }

  List<MapEntry<String, int>> _extractScoredSentences(String text) {
    final raw = text
        .split(_sentenceSplit)
        .map((line) => line.trim())
        .where((line) => line.length >= 10)
        .toList();

    final scored = <MapEntry<String, int>>[];

    for (final sentence in raw) {
      final normalized = _normalizeSentence(sentence);
      if (normalized.isEmpty) {
        continue;
      }

      final lower = normalized.toLowerCase();
      var score = 0;

      for (final signal in _strongSignals) {
        if (lower.contains(signal)) {
          score += 3;
        }
      }
      for (final signal in _progressSignals) {
        if (lower.contains(signal)) {
          score += 1;
        }
      }
      for (final signal in _effortSignals) {
        if (lower.contains(signal)) {
          score += 2;
        }
      }
      for (final signal in _negativeSignals) {
        if (lower.contains(signal)) {
          score -= 2;
        }
      }

      if (RegExp(r'\b(i|we)\b').hasMatch(lower)) {
        score += 1;
      }
      if (RegExp(r'\b(done|finished|submitted|sent|called|wrote|cleaned|cooked)\b')
          .hasMatch(lower)) {
        score += 1;
      }
      if (normalized.split(' ').length >= 6) {
        score += 1;
      }

      if (score >= 3) {
        scored.add(MapEntry(normalized, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    final unique = <String>{};
    final deduped = <MapEntry<String, int>>[];
    for (final entry in scored) {
      final key = entry.key.toLowerCase();
      if (unique.add(key)) {
        deduped.add(entry);
      }
    }

    return deduped.take(8).toList();
  }

  List<String> _normalizeAndDedupe(List<String> values) {
    final seen = <String>{};
    final out = <String>[];

    for (final item in values) {
      final normalized = _normalizeSentence(item);
      if (normalized.isEmpty) {
        continue;
      }
      final signature = normalized.toLowerCase();
      if (seen.add(signature)) {
        out.add(normalized);
      }
    }

    return out;
  }

  String _normalizeSentence(String input) {
    final clean = input.trim().replaceFirst(_bulletPrefix, '').trim();
    if (clean.isEmpty) {
      return '';
    }
    return clean[0].toUpperCase() + clean.substring(1);
  }
}
