import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../controllers/app_controller.dart';
import '../models/journal_entry.dart';
import '../services/voice_entry_service.dart';

class EntryEditorScreen extends StatefulWidget {
  const EntryEditorScreen({super.key, required this.controller, this.entry});

  final AppController controller;
  final JournalEntry? entry;

  @override
  State<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends State<EntryEditorScreen> {
  late final TextEditingController _journalController;
  final TextEditingController _winsInputController = TextEditingController();
  late bool _isBreakdown;
  late List<String> _manualWins;
  late List<String> _audioPaths;
  late List<int> _audioDurationMsList;
  bool _lockAfterSave = false;

  late final String _initialJournalText;
  late final bool _initialIsBreakdown;
  late final List<String> _initialManualWins;
  late final List<String> _initialAudioPaths;
  late final List<int> _initialAudioDurationMsList;
  late final bool _initialLockAfterSave;

  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _loadedPreviewPath;

  AppController get c => widget.controller;
  JournalEntry? get entry => widget.entry;

  bool get _isEditing => entry != null;

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: entry?.text ?? '');
    _isBreakdown = entry?.isBreakdownEntry ?? false;
    _manualWins = [...(entry?.manualWins ?? const <String>[])];
    _audioPaths = [...(entry?.resolvedAudioPaths ?? const <String>[])];
    _audioDurationMsList = [...(entry?.resolvedAudioDurations ?? const <int>[])];

    _initialJournalText = _journalController.text;
    _initialIsBreakdown = _isBreakdown;
    _initialManualWins = [..._manualWins];
    _initialAudioPaths = [..._audioPaths];
    _initialAudioDurationMsList = [..._audioDurationMsList];
    _initialLockAfterSave = _lockAfterSave;
  }

  @override
  void dispose() {
    _journalController.dispose();
    _winsInputController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = entry?.isPermanentlyLocked ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        final shouldLeave = await _onBackPressed();
        if (!shouldLeave || !context.mounted) {
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Journal entry' : 'Add new entry'),
          actions: [
            TextButton(
              onPressed: locked ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (locked)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'This entry is locked, so editing is no longer available.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  Text(_formatDate(entry?.date ?? DateTime.now())),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _journalController,
                    enabled: !locked,
                    minLines: 14,
                    maxLines: 22,
                    decoration: const InputDecoration(
                      hintText: 'Rant here...',
                      border: InputBorder.none,
                    ),
                  ),
                  if (_manualWins.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Wins', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    ..._manualWins.map((item) => Text('• $item')),
                    const SizedBox(height: 6),
                    FilledButton.tonal(
                      onPressed: locked ? null : _openWinsCallout,
                      child: const Text('+ Add More'),
                    ),
                  ],
                  if (_audioPaths.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Voice recordings (${_audioPaths.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(_audioPaths.length, (index) {
                      final path = _audioPaths[index];
                      final durationMs = index < _audioDurationMsList.length
                          ? _audioDurationMsList[index]
                          : null;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  durationMs == null
                                      ? 'Recording ${index + 1}'
                                      : 'Recording ${index + 1} (${(durationMs / 1000).toStringAsFixed(1)}s)',
                                ),
                              ),
                              StreamBuilder<PlayerState>(
                                stream: _previewPlayer.playerStateStream,
                                builder: (context, snapshot) {
                                  final playerState = snapshot.data;
                                  final isPlaying =
                                      (playerState?.playing ?? false) &&
                                      _loadedPreviewPath == path;
                                  return IconButton(
                                    onPressed: () => _togglePreview(path),
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle
                                          : Icons.play_circle,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _actionIconButton(
                        label: 'Breakdown',
                        icon: _isBreakdown ? Icons.toggle_on : Icons.toggle_off,
                        selected: _isBreakdown,
                        onTap: locked
                            ? null
                            : () {
                                setState(() {
                                  _isBreakdown = !_isBreakdown;
                                });
                              },
                      ),
                      _actionIconButton(
                        label: 'Add Wins',
                        icon: Icons.add,
                        onTap: locked ? null : _openWinsCallout,
                      ),
                      _actionIconButton(
                        label: 'Voice Entry',
                        icon: Icons.mic,
                        onTap: locked ? null : _openVoiceEntryCallout,
                      ),
                      _actionIconButton(
                        label: 'Lock forever',
                        icon: Icons.lock,
                        selected: _isEditing ? false : _lockAfterSave,
                        onTap: locked
                            ? null
                            : () {
                                if (_isEditing) {
                                  _confirmLockForever();
                                } else {
                                  setState(() {
                                    _lockAfterSave = !_lockAfterSave;
                                  });
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasUnsavedChanges {
    if (_journalController.text != _initialJournalText) {
      return true;
    }
    if (_isBreakdown != _initialIsBreakdown) {
      return true;
    }
    if (!listEquals(_manualWins, _initialManualWins)) {
      return true;
    }
    if (!listEquals(_audioPaths, _initialAudioPaths)) {
      return true;
    }
    if (!listEquals(_audioDurationMsList, _initialAudioDurationMsList)) {
      return true;
    }
    if (_lockAfterSave != _initialLockAfterSave) {
      return true;
    }
    return false;
  }

  Future<bool> _onBackPressed() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave without saving?'),
          content: const Text(
            'You have unsaved changes. If you go back now, your changes will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    return shouldLeave == true;
  }

  Future<void> _openWinsCallout() async {
    _winsInputController.clear();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Callout your win...'),
          content: TextField(
            controller: _winsInputController,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Record your win...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                final next = _winsInputController.text.trim();
                if (next.isEmpty) {
                  return;
                }
                setState(() {
                  _manualWins = [..._manualWins, next];
                });
                Navigator.pop(context);
              },
              child: const Text('Save Win'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openVoiceEntryCallout() async {
    var recording = false;
    var paused = false;
    var stoppedAndApplied = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Voice entry'),
                    const SizedBox(height: 8),
                    const Text(
                      'Start recording. You can pause/resume. Use Stop & use to attach this clip.',
                    ),
                    const SizedBox(height: 12),
                    if (recording)
                      Text(paused ? 'Paused' : 'Recording...'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: recording
                                ? null
                                : () async {
                                    final ok = await c.startVoiceCapture(
                                    );
                                    if (!ok) {
                                      if (!context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Microphone permission is required for voice entry.',
                                              ),
                                            ),
                                          );
                                      return;
                                    }

                                    setSheetState(() {
                                      recording = true;
                                      paused = false;
                                    });
                                  },
                            icon: const Icon(Icons.fiber_manual_record),
                            label: const Text('Start'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: recording
                                ? () async {
                                    final ok = paused
                                        ? await c.resumeVoiceCapture()
                                        : await c.pauseVoiceCapture();
                                    if (!ok) {
                                      return;
                                    }
                                    setSheetState(() {
                                      paused = !paused;
                                    });
                                  }
                                : null,
                            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                            label: Text(paused ? 'Resume' : 'Pause'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: recording
                                ? () async {
                                    final result = await c.stopVoiceCapture();
                                    if (result == null) {
                                      setSheetState(() {
                                        recording = false;
                                        paused = false;
                                      });
                                      return;
                                    }

                                    if (!sheetContext.mounted) {
                                      final file = File(result.audioPath);
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                      return;
                                    }

                                    final shouldSave = await showDialog<bool>(
                                      context: sheetContext,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Save this recording?'),
                                          content: const Text(
                                            'Do you want to attach this voice clip to the entry?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Discard'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    setSheetState(() {
                                      recording = false;
                                      paused = false;
                                    });

                                    if (shouldSave == true) {
                                      stoppedAndApplied = true;
                                      _applyVoiceResult(result);
                                    } else {
                                      final file = File(result.audioPath);
                                      if (await file.exists()) {
                                        await file.delete();
                                      }
                                    }

                                    if (!sheetContext.mounted) {
                                      return;
                                    }
                                    Navigator.of(sheetContext).pop();
                                  }
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop & use'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            onPressed: recording
                                ? () async {
                                    await c.cancelVoiceCapture();
                                    if (!sheetContext.mounted) {
                                      return;
                                    }
                                    Navigator.of(sheetContext).pop();
                                  }
                                : () {
                                    Navigator.of(sheetContext).pop();
                                  },
                            child: Text(recording ? 'Cancel recording' : 'Close'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (recording && !stoppedAndApplied) {
      await c.cancelVoiceCapture();
    }
  }

  void _applyVoiceResult(VoiceCaptureResult result) {
    final hasAudioPath = result.audioPath.trim().isNotEmpty;
    if (!hasAudioPath) {
      return;
    }
    _audioPaths = [..._audioPaths, result.audioPath];
    _audioDurationMsList = [..._audioDurationMsList, result.audioDurationMs];
    setState(() {});
  }

  Future<void> _togglePreview(String path) async {
    try {
      if (_loadedPreviewPath != path) {
        await _previewPlayer.setFilePath(path);
        _loadedPreviewPath = path;
      }

      if (_previewPlayer.playing) {
        await _previewPlayer.pause();
      } else {
        await _previewPlayer.play();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play this recording.')),
      );
    }
  }

  Future<void> _confirmLockForever() async {
    final shouldLock = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lock this entry forever?'),
          content: const Text(
            'After locking, this entry cannot be edited again.',
          ),
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

    if (shouldLock != true || entry == null) {
      return;
    }

    await c.lockEntryForever(entry!.id);
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _actionIconButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool selected = false,
  }) {
    final selectedBg = Theme.of(context).colorScheme.primary;
    final selectedFg = Theme.of(context).colorScheme.onPrimary;
    final normalBg = Theme.of(context).colorScheme.secondaryContainer;
    final normalFg = Theme.of(context).colorScheme.onSecondaryContainer;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? selectedBg : normalBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? selectedFg : normalFg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? selectedBg : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = _monthNames[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  Future<void> _save() async {
    final savedId = await c.saveEntry(
      entryId: entry?.id,
      journalText: _journalController.text,
      manualWinsMultiline: _manualWins.join('\n'),
      isBreakdownEntry: _isBreakdown,
      audioPaths: _audioPaths,
      audioDurationMsList: _audioDurationMsList,
    );

    if (!_isEditing && _lockAfterSave && savedId != null) {
      await c.lockEntryForever(savedId);
    }

    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
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
