import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/app_controller.dart';
import '../models/app_settings.dart';
import '../models/breakdown_record.dart';
import 'entry_detail_screen.dart';
import 'entry_editor_screen.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildEntriesTab(context),
      _buildBreakdownsTab(context),
      _buildSettingsTab(context),
    ];
    final titles = ['Entries', 'Breakdowns', 'Settings'];

    return Scaffold(
      appBar: AppBar(title: Text('Leave It Here · ${titles[c.selectedTab]}')),
      body: pages[c.selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: c.selectedTab,
        onDestinationSelected: (value) {
          setState(() {
            c.selectedTab = value;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Entries'),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Breakdowns',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildEntriesTab(BuildContext context) {
    final entries = c.sortedEntries;
    final accent = Theme.of(context).colorScheme.primaryContainer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: accent,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add new entries',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('Write, reflect, add wins, or voice notes.'),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _openNewEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Past entries', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            SegmentedButton<EntryViewMode>(
              segments: const [
                ButtonSegment(
                  value: EntryViewMode.list,
                  icon: Icon(Icons.view_list),
                  label: Text('List'),
                ),
                ButtonSegment(
                  value: EntryViewMode.grid,
                  icon: Icon(Icons.grid_view),
                  label: Text('Grid'),
                ),
              ],
              selected: {c.settings.entryViewMode},
              onSelectionChanged: (selected) async {
                await c.updateSettings(
                  c.settings.copyWith(entryViewMode: selected.first),
                );
                if (!mounted) {
                  return;
                }
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No entries yet.'),
            ),
          )
        else if (c.settings.entryViewMode == EntryViewMode.grid)
          GridView.builder(
            itemCount: entries.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _entryCard(context, entry, compact: true);
            },
          )
        else
          ...entries.map((entry) => _entryCard(context, entry, compact: false)),
      ],
    );
  }

  Widget _entryCard(BuildContext context, dynamic entry, {required bool compact}) {
    final winsToShow = entry.manualWins.isNotEmpty
        ? entry.manualWins
        : entry.smartHighlights;
    final preview = entry.text.trim();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEntryDetail(entry.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDateTime(entry.date),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              if (entry.isBreakdownEntry)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Chip(
                    label: const Text('Breakdown'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Text(
                preview,
                maxLines: compact ? 4 : 6,
                overflow: TextOverflow.ellipsis,
              ),
              if (!compact && winsToShow.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(entry.manualWins.isNotEmpty ? 'Your wins' : 'Suggested wins'),
                const SizedBox(height: 4),
                ...winsToShow.take(3).map((item) => Text('• $item')),
              ],
              if (entry.isPermanentlyLocked)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Locked forever'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownsTab(BuildContext context) {
    final records = c.breakdowns;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Breakdown reflections', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reflection view'),
                const SizedBox(height: 8),
                SegmentedButton<ReflectionView>(
                  segments: const [
                    ButtonSegment(
                      value: ReflectionView.dropdown,
                      label: Text('Dropdown'),
                    ),
                    ButtonSegment(
                      value: ReflectionView.calendar,
                      label: Text('Calendar'),
                    ),
                  ],
                  selected: {c.settings.reflectionView},
                  onSelectionChanged: (selected) async {
                    await c.updateSettings(
                      c.settings.copyWith(reflectionView: selected.first),
                    );
                    if (!mounted) {
                      return;
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (c.settings.reflectionView == ReflectionView.calendar)
          _buildCalendarView(context)
        else if (records.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No breakdown records yet.'),
            ),
          )
        else
          ...records.map((record) => _breakdownCard(context, record)),
      ],
    );
  }

  Widget _breakdownCard(BuildContext context, BreakdownRecord record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatDateTime(record.date)),
            if (record.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                record.note,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Chip(
              label: const Text('Breakdown'),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _openBreakdownDetail(record.id),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TableCalendar<void>(
          firstDay: DateTime(2000),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: c.calendarFocusedDay,
          selectedDayPredicate: (day) =>
              c.calendarSelectedDay != null && isSameDay(day, c.calendarSelectedDay),
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          headerStyle: const HeaderStyle(formatButtonVisible: false),
          onPageChanged: (focused) {
            c.calendarFocusedDay = focused;
          },
          onDaySelected: (selected, focused) async {
            setState(() {
              c.calendarSelectedDay = selected;
              c.calendarFocusedDay = focused;
            });

            final records = c.breakdownsOnDay(selected);
            if (records.isEmpty) {
              return;
            }

            final first = records.first;
            _openBreakdownDetail(first.id);
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, _) {
              if (!c.hasBreakdownOnDay(day)) {
                return null;
              }
              return _highlightDay(context, day, false);
            },
            todayBuilder: (context, day, _) {
              if (!c.hasBreakdownOnDay(day)) {
                return null;
              }
              return _highlightDay(context, day, true);
            },
          ),
        ),
      ),
    );
  }

  Widget _highlightDay(BuildContext context, DateTime day, bool isToday) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isToday ? colorScheme.primaryContainer : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text('${day.day}'),
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily reminder'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: c.settings.dailyReminderEnabled,
                  title: const Text('Remind me daily'),
                  subtitle: Text(
                    'At ${_formatTime(c.settings.reminderHour, c.settings.reminderMinute)}',
                  ),
                  onChanged: (value) async {
                    await c.updateSettings(
                      c.settings.copyWith(dailyReminderEnabled: value),
                    );
                  },
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: c.settings.reminderHour,
                        minute: c.settings.reminderMinute,
                      ),
                    );
                    if (picked == null) {
                      return;
                    }
                    await c.updateSettings(
                      c.settings.copyWith(
                        reminderHour: picked.hour,
                        reminderMinute: picked.minute,
                      ),
                    );
                  },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Change reminder time'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('App lock'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: c.settings.lockEnabled,
                  title: const Text('Enable app lock'),
                  onChanged: (value) async {
                    if (!value) {
                      await c.updateSettings(
                        c.settings.copyWith(lockEnabled: false),
                      );
                      return;
                    }

                    var hasPin = await c.hasPin();
                    if (!mounted) {
                      return;
                    }

                    if (!hasPin) {
                      final pin = await _askPinWithConfirmation(
                        this.context,
                        title: 'Set PIN before enabling lock',
                      );
                      if (!mounted) {
                        return;
                      }

                      if (pin == null) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Lock not enabled. PIN setup cancelled.'),
                          ),
                        );
                        return;
                      }
                      await c.setPin(pin);
                      hasPin = true;
                    }

                    if (hasPin) {
                      await c.updateSettings(
                        c.settings.copyWith(lockEnabled: true),
                      );
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: c.settings.biometricEnabled,
                  title: const Text('Use biometric when available'),
                  subtitle: Text(
                    c.biometricAvailable ? 'Available' : 'Unavailable',
                  ),
                  onChanged: c.biometricAvailable
                      ? (value) async {
                          await c.updateSettings(
                            c.settings.copyWith(biometricEnabled: value),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 8),
                Text('Lock timeout: ${c.settings.lockTimeoutMinutes} min'),
                Slider(
                  min: 1,
                  max: 30,
                  divisions: 29,
                  value: c.settings.lockTimeoutMinutes.toDouble(),
                  onChanged: (value) async {
                    await c.updateSettings(
                      c.settings.copyWith(lockTimeoutMinutes: value.round()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    final hasPin = await c.hasPin();
                    if (!mounted) {
                      return;
                    }

                    if (hasPin) {
                      final currentPin = await _askPinOnly(
                        this.context,
                        title: 'Enter current PIN',
                      );
                      if (!mounted) {
                        return;
                      }
                      if (currentPin == null || currentPin.isEmpty) {
                        return;
                      }

                      final verified = await c.verifyPin(currentPin);
                      if (!mounted) {
                        return;
                      }
                      if (!verified) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Current PIN is incorrect'),
                          ),
                        );
                        return;
                      }
                    }

                    final pin = await _askPinWithConfirmation(
                      this.context,
                      title: 'Set PIN (4-8 digits)',
                    );
                    if (!mounted) {
                      return;
                    }
                    if (pin == null) {
                      return;
                    }
                    await c.setPin(pin);
                    if (!mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('PIN updated')),
                    );
                  },
                  child: const Text('Set / Change PIN'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme mode'),
                const SizedBox(height: 8),
                SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {c.settings.themeMode},
                  onSelectionChanged: (selected) async {
                    await c.updateSettings(
                      c.settings.copyWith(themeMode: selected.first),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tutorial'),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _openTutorial,
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('View tutorial'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _askPinWithConfirmation(
    BuildContext context, {
    required String title,
  }) async {
    var pinValue = '';
    var confirmValue = '';

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final pinValid = pinValue.length >= 4 && pinValue.length <= 8;
            final matches = pinValue == confirmValue && confirmValue.isNotEmpty;

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        pinValue = value.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      counterText: '',
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        confirmValue = value.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      !pinValid
                          ? 'PIN must be 4-8 digits'
                          : !matches
                          ? 'PINs do not match'
                          : 'PIN ready',
                      style: TextStyle(
                        color: !pinValid || !matches
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: pinValid && matches
                      ? () => Navigator.pop(context, pinValue)
                      : null,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    return value;
  }

  Future<String?> _askPinOnly(
    BuildContext context, {
    required String title,
  }) async {
    var pinValue = '';

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final pinValid = pinValue.length >= 4 && pinValue.length <= 8;
            return AlertDialog(
              title: Text(title),
              content: TextField(
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                ),
                onChanged: (value) {
                  setDialogState(() {
                    pinValue = value.trim();
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: pinValid
                      ? () => Navigator.pop(context, pinValue)
                      : null,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    return value;
  }

  Future<void> _openNewEntry() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryEditorScreen(controller: c)),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openEntryDetail(String entryId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(controller: c, entryId: entryId),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openBreakdownDetail(String breakdownId) async {
    final record = c.breakdowns.firstWhere((item) => item.id == breakdownId);
    final linked = c.findEntryForBreakdown(breakdownId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<List<String>>(
              future: c.getBreakdownHighlights(record),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Breakdown details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_formatDateTime(record.date)),
                    if (record.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(record.note),
                    ],
                    const SizedBox(height: 12),
                    const Text('Top wins in this breakdown window:'),
                    const SizedBox(height: 6),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator(strokeWidth: 2)
                    else if (items.isEmpty)
                      const Text('No highlights available yet.')
                    else
                      ...items.map((item) => Text('• $item')),
                    const SizedBox(height: 12),
                    if (linked != null && !linked.isPermanentlyLocked)
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await Navigator.of(this.context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => EntryEditorScreen(
                                controller: c,
                                entry: linked,
                              ),
                            ),
                          );
                          if (!mounted) {
                            return;
                          }
                          setState(() {});
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    if (linked != null && linked.isPermanentlyLocked)
                      const Text(
                        'This linked breakdown entry is locked, so edit is unavailable.',
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTutorial() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TutorialScreen(
          showSkip: false,
          onDone: () async {},
        ),
      ),
    );
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

  String _formatTime(int hour, int minute) {
    final hour12 = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final mm = minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$mm $period';
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
