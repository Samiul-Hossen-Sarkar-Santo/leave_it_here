import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../controllers/app_controller.dart';
import '../models/journal_entry.dart';
import 'entry_editor_screen.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({
    super.key,
    required this.controller,
    required this.entryId,
  });

  final AppController controller;
  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  AppController get c => widget.controller;

  final AudioPlayer _player = AudioPlayer();
  String? _loadedAudioPath;
  String? _audioError;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = c.getEntryById(widget.entryId);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Entry')),
        body: const Center(child: Text('Entry not found.')),
      );
    }

    final wins = entry.manualWins.isNotEmpty ? entry.manualWins : entry.smartHighlights;
    final audioPaths = entry.resolvedAudioPaths;

    return Scaffold(
      appBar: AppBar(title: const Text('Journal entry')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (entry.isPermanentlyLocked)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'This entry has been locked, so edit actions are hidden.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          Text(_formatDateTime(entry.date), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(entry.text),
          if (wins.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              entry.manualWins.isNotEmpty ? 'Your wins' : 'Suggested wins',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...wins.map((item) => Text('• $item')),
          ],
          if (audioPaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Voice notes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_audioError != null)
              Text(_audioError!)
            else
              ...List.generate(audioPaths.length, (index) {
                final path = audioPaths[index];
                final durationMs = index < entry.resolvedAudioDurations.length
                    ? entry.resolvedAudioDurations[index]
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAudioPlayer(path, durationMs),
                );
              }),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: entry.isPermanentlyLocked
                      ? null
                      : () => _openEditor(entry),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: entry.isPermanentlyLocked
                    ? null
                    : () => _lockForever(entry),
                icon: const Icon(Icons.lock),
                label: const Text('Lock forever'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String path, int? durationMs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              durationMs == null
                  ? 'Voice clip'
                  : 'Voice clip (${(durationMs / 1000).toStringAsFixed(1)}s)',
            ),
            const SizedBox(height: 8),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final isPlaying =
                    (playerState?.playing ?? false) && _loadedAudioPath == path;

                return FilledButton.tonalIcon(
                  onPressed: () async {
                    await _togglePlay(path);
                  },
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                );
              },
            ),
            const SizedBox(height: 10),
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _player.duration ??
                  Duration(milliseconds: durationMs ?? 0);
                final totalMs = duration.inMilliseconds;
                final posMs = position.inMilliseconds.clamp(0, totalMs == 0 ? 1 : totalMs);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: totalMs == 0 ? 0 : posMs / totalMs,
                    ),
                    const SizedBox(height: 6),
                    Text('${_fmt(position)} / ${_fmt(duration)}'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlay(String audioPath) async {
    try {
      if (_loadedAudioPath != audioPath) {
        await _player.setFilePath(audioPath);
        _loadedAudioPath = audioPath;
      }

      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _audioError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _audioError = 'Could not load voice note from this device path.';
      });
    }
  }

  String _fmt(Duration value) {
    final mins = value.inMinutes.toString().padLeft(2, '0');
    final secs = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _openEditor(JournalEntry entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(controller: c, entry: entry),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _lockForever(JournalEntry entry) async {
    final shouldLock = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lock this entry forever?'),
          content: const Text('After this, this entry cannot be edited.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lock forever'),
            ),
          ],
        );
      },
    );

    if (shouldLock != true) {
      return;
    }

    await c.lockEntryForever(entry.id);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  String _formatDateTime(DateTime date) {
    final month = _monthNames[date.month - 1];
    final hour12 = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} $month ${date.year}, $hour12:$minute $period';
  }
}

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
