import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../controllers/app_controller.dart';
import '../models/app_settings.dart';
import '../models/breakdown_record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _journalController = TextEditingController();
  final _manualWinsController = TextEditingController();
  final _breakdownNoteController = TextEditingController();

  @override
  void dispose() {
    _journalController.dispose();
    _manualWinsController.dispose();
    _breakdownNoteController.dispose();
    super.dispose();
  }

  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildJournalTab(context),
      _buildBreakdownsTab(context),
      _buildHistoryTab(context),
      _buildSettingsTab(context),
    ];
    final titles = ['Journal', 'Breakdowns', 'History', 'Settings'];

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
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Breakdowns'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildJournalTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s journal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _journalController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'How was today?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _manualWinsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Wins (one per line)',
                    hintText: 'One win per line',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await c.addJournalEntry(
                      journalText: _journalController.text,
                      manualWinsMultiline: _manualWinsController.text,
                    );
                    _journalController.clear();
                    _manualWinsController.clear();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add_task),
                  label: const Text('Save today\'s entry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Breakdown log', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _breakdownNoteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Short note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await c.addBreakdownNow(note: _breakdownNoteController.text);
                    _breakdownNoteController.clear();
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('Log breakdown now'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Breakdown reflections', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (c.settings.reflectionView == ReflectionView.dropdown)
          _buildDropdownView(context)
        else
          _buildCalendarView(context),
      ],
    );
  }

  Widget _buildDropdownView(BuildContext context) {
    if (c.breakdowns.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No breakdown records yet.'),
        ),
      );
    }

    return Column(
      children: c.breakdowns.map((record) {
        return Card(
          child: ExpansionTile(
            title: Text(_formatDateTime(record.date)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              FutureBuilder<List<String>>(
                future: c.getBreakdownHighlights(record),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  return _buildBreakdownDetail(record, items);
                },
              ),
            ],
          ),
        );
      }).toList(),
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

            await showModalBottomSheet<void>(
              context: context,
              builder: (context) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      shrinkWrap: true,
                      children: records
                          .map((record) => FutureBuilder<List<String>>(
                                future: c.getBreakdownHighlights(record),
                                builder: (context, snapshot) {
                                  final items = snapshot.data ?? [];
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: _buildBreakdownDetail(record, items),
                                    ),
                                  );
                                },
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            );
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

  Widget _buildBreakdownDetail(BreakdownRecord record, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatDateTime(record.date)),
        if (record.note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(record.note),
        ],
        const SizedBox(height: 8),
        const Text('Top wins in this breakdown window:'),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Text('No highlights available yet.')
        else
          ...items.map((item) => Text('• $item')),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (c.entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No entries yet.'),
            ),
          ),
        ...c.entries.map((entry) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDateTime(entry.date)),
                  const SizedBox(height: 6),
                  Text(entry.text),
                  if (entry.smartHighlights.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Extracted wins'),
                    ...entry.smartHighlights.map((item) => Text('• $item')),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
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
                    await c.updateSettings(c.settings.copyWith(dailyReminderEnabled: value));
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
                const Text('Theme mode'),
                const SizedBox(height: 8),
                SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(value: AppThemeMode.system, label: Text('System')),
                    ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {c.settings.themeMode},
                  onSelectionChanged: (selected) async {
                    await c.updateSettings(c.settings.copyWith(themeMode: selected.first));
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
                const Text('Breakdown reflections'),
                const SizedBox(height: 8),
                SegmentedButton<ReflectionView>(
                  segments: const [
                    ButtonSegment(value: ReflectionView.dropdown, label: Text('Dropdown')),
                    ButtonSegment(value: ReflectionView.calendar, label: Text('Calendar')),
                  ],
                  selected: {c.settings.reflectionView},
                  onSelectionChanged: (selected) async {
                    await c.updateSettings(c.settings.copyWith(reflectionView: selected.first));
                  },
                ),
                const SizedBox(height: 10),
                Text('Wins per breakdown: ${c.settings.winsPerBreakdown}'),
                Slider(
                  value: c.settings.winsPerBreakdown.toDouble(),
                  min: 1,
                  max: 12,
                  divisions: 11,
                  label: '${c.settings.winsPerBreakdown}',
                  onChanged: (value) async {
                    await c.updateSettings(
                      c.settings.copyWith(winsPerBreakdown: value.round()),
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
                const Text('App lock'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: c.settings.lockEnabled,
                  title: const Text('Enable app lock'),
                  onChanged: (value) async {
                    if (!value) {
                      await c.updateSettings(c.settings.copyWith(lockEnabled: false));
                      return;
                    }

                    var hasPin = await c.hasPin();
                    if (!mounted) {
                      return;
                    }

                    if (!hasPin) {
                      if (!mounted) {
                        return;
                      }

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
                      await c.updateSettings(c.settings.copyWith(lockEnabled: true));
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: c.settings.biometricEnabled,
                  title: const Text('Use biometric when available'),
                  subtitle: Text(c.biometricAvailable ? 'Available' : 'Unavailable'),
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
                    final pin = await _askPinWithConfirmation(
                      context,
                      title: 'Set PIN (4-8 digits)',
                    );
                    if (pin == null) {
                      return;
                    }
                    await c.setPin(pin);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN updated')),
                      );
                    }
                  },
                  child: const Text('Set / Change PIN'),
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
