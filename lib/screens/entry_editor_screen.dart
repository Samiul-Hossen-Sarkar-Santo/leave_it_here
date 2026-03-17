import 'package:flutter/material.dart';

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
  String? _audioPath;
  int? _audioDurationMs;
  bool _lockAfterSave = false;

  AppController get c => widget.controller;
  JournalEntry? get entry => widget.entry;

  bool get _isEditing => entry != null;

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: entry?.text ?? '');
    _isBreakdown = entry?.isBreakdownEntry ?? false;
    _manualWins = [...(entry?.manualWins ?? const <String>[])];
    _audioPath = entry?.audioPath;
    _audioDurationMs = entry?.audioDurationMs;
  }

  @override
  void dispose() {
    _journalController.dispose();
    _winsInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = entry?.isPermanentlyLocked ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit entry' : 'New entry'),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () {
                setState(() {
                  _lockAfterSave = !_lockAfterSave;
                });
              },
              icon: Icon(_lockAfterSave ? Icons.lock : Icons.lock_open),
              tooltip: _lockAfterSave
                  ? 'Will lock after save'
                  : 'Lock after save',
            ),
          if (_isEditing && !locked)
            IconButton(
              onPressed: _confirmLockForever,
              icon: const Icon(Icons.lock),
              tooltip: 'Lock forever',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 8),
          TextField(
            controller: _journalController,
            enabled: !locked,
            minLines: 8,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: 'Write your entry',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isBreakdown,
            onChanged: locked
                ? null
                : (value) {
                    setState(() {
                      _isBreakdown = value;
                    });
                  },
            title: const Text('Mark as breakdown entry'),
          ),
          const SizedBox(height: 6),
          FilledButton.tonalIcon(
            onPressed: locked ? null : _openWinsCallout,
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Add wins'),
          ),
          if (_manualWins.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._manualWins.map((item) => Text('• $item')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: locked ? null : _openWinsCallout,
              icon: const Icon(Icons.add),
              label: const Text('Add more+'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: locked ? null : _openVoiceEntryCallout,
            icon: const Icon(Icons.mic_none),
            label: const Text('Voice entry'),
          ),
          if (_audioPath != null) ...[
            const SizedBox(height: 8),
            Text(
              _audioDurationMs == null
                  ? 'Voice recording attached'
                  : 'Voice recording attached (${(_audioDurationMs! / 1000).toStringAsFixed(1)}s)',
            ),
          ],
          if (!_isEditing && _lockAfterSave) ...[
            const SizedBox(height: 8),
            const Text('This entry will be locked after save.'),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: locked ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Save changes' : 'Save entry'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWinsCallout() async {
    _winsInputController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final insets = MediaQuery.viewInsetsOf(context);
        return SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(16, 16, 16, insets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add a win'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _winsInputController,
                    autofocus: true,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Write a win',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVoiceEntryCallout() async {
    var recording = false;
    var stoppedAndApplied = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
                    const Text('Start recording and stop to save voice log.'),
                    const SizedBox(height: 12),
                    if (recording)
                      const Text('Recording...'),
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
                                    final result = await c.stopVoiceCapture();
                                    if (result == null) {
                                      setSheetState(() {
                                        recording = false;
                                      });
                                      return;
                                    }

                                    setSheetState(() {
                                      recording = false;
                                      stoppedAndApplied = true;
                                    });
                                    _applyVoiceResult(result);
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
                      ],
                    ),
                    if (recording) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () async {
                          await c.cancelVoiceCapture();
                          if (!sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Cancel recording'),
                      ),
                    ],
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
    _audioPath = hasAudioPath ? result.audioPath : null;
    _audioDurationMs = hasAudioPath ? result.audioDurationMs : null;
    setState(() {});
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

  Future<void> _save() async {
    final savedId = await c.saveEntry(
      entryId: entry?.id,
      journalText: _journalController.text,
      manualWinsMultiline: _manualWins.join('\n'),
      isBreakdownEntry: _isBreakdown,
      audioPath: _audioPath,
      audioDurationMs: _audioDurationMs,
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
