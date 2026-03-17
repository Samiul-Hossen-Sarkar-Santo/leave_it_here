import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LeaveItHereApp());
}

class LeaveItHereApp extends StatelessWidget {
  const LeaveItHereApp({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9AAFA9),
      brightness: Brightness.light,
    ).copyWith(surface: const Color(0xFFF4F7F5));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leave It Here',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: palette,
        scaffoldBackgroundColor: const Color(0xFFEEF2EF),
      ),
      home: const HomeScreen(),
    );
  }
}

enum ReflectionView { dropdown, calendar }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _journalController = TextEditingController();
  final TextEditingController _manualWinsController = TextEditingController();
  final TextEditingController _breakdownNoteController = TextEditingController();

  bool _notificationsReady = false;
  bool _notificationPermissionGranted = true;

  List<JournalEntry> _entries = [];
  List<BreakdownRecord> _breakdowns = [];
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 30);
  bool _dailyReminderEnabled = false;
  ReflectionView _reflectionView = ReflectionView.dropdown;

  DateTime _calendarFocusedDay = DateTime.now();
  DateTime? _calendarSelectedDay;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _manualWinsController.dispose();
    _breakdownNoteController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    try {
      await _initNotifications();
    } catch (_) {
      _notificationsReady = false;
      _notificationPermissionGranted = false;
    }
    await _loadData();
  }

  Future<void> _initNotifications() async {
    await AwesomeNotifications().initialize(null, [
      NotificationChannel(
        channelKey: 'daily_journal_reminder',
        channelName: 'Daily Journal Reminder',
        channelDescription: 'Reminds you to log today\'s wins.',
        defaultColor: const Color(0xFF9AAFA9),
        ledColor: Colors.white,
        importance: NotificationImportance.Default,
      ),
    ]);

    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      _notificationPermissionGranted =
          await AwesomeNotifications().requestPermissionToSendNotifications();
    } else {
      _notificationPermissionGranted = true;
    }

    _notificationsReady = true;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesRaw = prefs.getString(_StorageKeys.entries);
    final breakdownsRaw = prefs.getString(_StorageKeys.breakdowns);

    final loadedEntries = entriesRaw == null
        ? <JournalEntry>[]
        : (jsonDecode(entriesRaw) as List<dynamic>)
              .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
              .toList();

    final loadedBreakdowns = breakdownsRaw == null
        ? <BreakdownRecord>[]
        : (jsonDecode(breakdownsRaw) as List<dynamic>)
              .map(
                (item) => BreakdownRecord.fromJson(item as Map<String, dynamic>),
              )
              .toList();

    final reminderHour = prefs.getInt(_StorageKeys.reminderHour) ?? 20;
    final reminderMinute = prefs.getInt(_StorageKeys.reminderMinute) ?? 30;
    final reminderEnabled = prefs.getBool(_StorageKeys.reminderEnabled) ?? false;
    final reflectionRaw = prefs.getString(_StorageKeys.reflectionView) ?? 'dropdown';

    setState(() {
      _entries = loadedEntries..sort((a, b) => b.date.compareTo(a.date));
      _breakdowns = loadedBreakdowns..sort((a, b) => b.date.compareTo(a.date));
      _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
      _dailyReminderEnabled = reminderEnabled;
      _reflectionView = ReflectionView.values.firstWhere(
        (view) => view.name == reflectionRaw,
        orElse: () => ReflectionView.dropdown,
      );
    });

    if (reminderEnabled) {
      await _scheduleDailyReminder();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _StorageKeys.entries,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _StorageKeys.breakdowns,
      jsonEncode(_breakdowns.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt(_StorageKeys.reminderHour, _reminderTime.hour);
    await prefs.setInt(_StorageKeys.reminderMinute, _reminderTime.minute);
    await prefs.setBool(_StorageKeys.reminderEnabled, _dailyReminderEnabled);
    await prefs.setString(_StorageKeys.reflectionView, _reflectionView.name);
  }

  Future<void> _scheduleDailyReminder() async {
    if (!_notificationsReady || !_notificationPermissionGranted) {
      return;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 101,
        channelKey: 'daily_journal_reminder',
        title: 'A gentle check-in',
        body: 'Log one good thing you did today 🌿',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
        second: 0,
        repeats: true,
        preciseAlarm: true,
        allowWhileIdle: true,
      ),
    );
  }

  Future<void> _cancelDailyReminder() async {
    if (!_notificationsReady) {
      return;
    }
    await AwesomeNotifications().cancel(101);
  }

  Future<void> _toggleReminder(bool enabled) async {
    setState(() {
      _dailyReminderEnabled = enabled;
    });

    if (enabled) {
      await _scheduleDailyReminder();
    } else {
      await _cancelDailyReminder();
    }

    await _saveData();
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Daily reminder time',
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _reminderTime = selected;
    });
    if (_dailyReminderEnabled) {
      await _scheduleDailyReminder();
    }
    await _saveData();
  }

  Future<void> _addJournalEntry() async {
    final journal = _journalController.text.trim();
    if (journal.isEmpty) {
      return;
    }

    final manualWins = _manualWinsController.text
        .split(RegExp(r'\n|,'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final smartHighlights = SmartHighlightExtractor.extract(
      text: journal,
      manualWins: manualWins,
    );

    final entry = JournalEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      text: journal,
      manualWins: manualWins,
      smartHighlights: smartHighlights,
    );

    setState(() {
      _entries = [entry, ..._entries]..sort((a, b) => b.date.compareTo(a.date));
      _journalController.clear();
      _manualWinsController.clear();
    });

    await _saveData();
  }

  Future<void> _addBreakdownRecordNow() async {
    final record = BreakdownRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      note: _breakdownNoteController.text.trim(),
    );

    setState(() {
      _breakdowns = [record, ..._breakdowns]..sort(
        (a, b) => b.date.compareTo(a.date),
      );
      _breakdownNoteController.clear();
    });

    await _saveData();
  }

  Future<void> _setReflectionView(ReflectionView view) async {
    setState(() {
      _reflectionView = view;
    });
    await _saveData();
  }

  List<String> _achievementsSince(DateTime date) {
    final relevant = _entries.where((entry) => !entry.date.isBefore(date));

    final items = <String>{};
    for (final entry in relevant) {
      items.addAll(entry.manualWins);
      items.addAll(entry.smartHighlights);
    }

    return items.toList()..sort();
  }

  List<BreakdownRecord> _breakdownsOnDay(DateTime day) {
    return _breakdowns
        .where(
          (record) =>
              record.date.year == day.year &&
              record.date.month == day.month &&
              record.date.day == day.day,
        )
        .toList();
  }

  bool _hasBreakdownOnDay(DateTime day) {
    return _breakdowns.any(
      (record) =>
          record.date.year == day.year &&
          record.date.month == day.month &&
          record.date.day == day.day,
    );
  }

  Future<void> _showBreakdownDayModal(DateTime day) async {
    final dayRecords = _breakdownsOnDay(day);
    if (dayRecords.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breakdown details · ${_formatDay(day)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: dayRecords.length,
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final record = dayRecords[index];
                      final wins = _achievementsSince(record.date);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateTime(record.date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (record.note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(record.note),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Meaningful things since then:',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          if (wins.isEmpty)
                            const Text('No highlights yet.')
                          else
                            ...wins.take(8).map((item) => Text('• $item')),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildJournalTab(context),
      _buildBreakdownTab(context),
      _buildEntriesTab(context),
      _buildSettingsTab(context),
    ];

    final titles = ['Journal', 'Breakdowns', 'History', 'Settings'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Leave It Here · ${titles[_selectedTab]}'),
        centerTitle: false,
      ),
      body: pages[_selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Journal'),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Breakdowns',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildJournalTab(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'A soft place to remember what you have accomplished.',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s journal', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _journalController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'How was today?',
                    hintText: 'Write freely. We will extract your meaningful wins.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _manualWinsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Wins you want to keep (optional)',
                    hintText: 'One per line or comma-separated',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _addJournalEntry,
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

  Widget _buildBreakdownTab(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Breakdown log', style: textTheme.titleMedium),
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
                  onPressed: _addBreakdownRecordNow,
                  icon: const Icon(Icons.bookmark_add),
                  label: const Text('Log breakdown now'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Breakdown reflections', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_reflectionView == ReflectionView.dropdown)
          _buildDropdownReflectionView(context)
        else
          _buildCalendarReflectionView(context),
      ],
    );
  }

  Widget _buildDropdownReflectionView(BuildContext context) {
    if (_breakdowns.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Tap "Log breakdown now" to start tracking progress.'),
        ),
      );
    }

    return Column(
      children: _breakdowns.map((record) {
        final wins = _achievementsSince(record.date);
        return Card(
          child: ExpansionTile(
            title: Text(_formatDateTime(record.date)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              if (record.note.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(record.note),
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Meaningful things since then:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 6),
              if (wins.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No highlights yet. Keep logging daily.'),
                )
              else
                ...wins.take(8).map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text('• $item'),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarReflectionView(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tap a highlighted date to see breakdown details.'),
            const SizedBox(height: 8),
            TableCalendar<void>(
              firstDay: DateTime(2000),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _calendarFocusedDay,
              selectedDayPredicate: (day) =>
                  _calendarSelectedDay != null && isSameDay(day, _calendarSelectedDay),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              headerStyle: const HeaderStyle(formatButtonVisible: false),
              onDaySelected: (selectedDay, focusedDay) async {
                setState(() {
                  _calendarSelectedDay = selectedDay;
                  _calendarFocusedDay = focusedDay;
                });
                await _showBreakdownDayModal(selectedDay);
              },
              onPageChanged: (focusedDay) {
                _calendarFocusedDay = focusedDay;
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (!_hasBreakdownOnDay(day)) {
                    return null;
                  }
                  return _buildHighlightedDay(context, day, isToday: false);
                },
                todayBuilder: (context, day, focusedDay) {
                  if (!_hasBreakdownOnDay(day)) {
                    return null;
                  }
                  return _buildHighlightedDay(context, day, isToday: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedDay(
    BuildContext context,
    DateTime day, {
    required bool isToday,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isToday ? colors.primaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEntriesTab(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Recent journal entries', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No entries yet. Start with one good thing today.'),
            ),
          ),
        ..._entries.take(20).map((entry) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDateTime(entry.date), style: textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(entry.text),
                  if (entry.smartHighlights.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Meaningful wins', style: textTheme.labelLarge),
                    const SizedBox(height: 4),
                    ...entry.smartHighlights.map((h) => Text('• $h')),
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
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily reminder', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _dailyReminderEnabled,
                  title: const Text('Remind me to log today'),
                  subtitle: Text('Every day at ${_reminderTime.format(context)}'),
                  onChanged: _toggleReminder,
                ),
                if (!_notificationPermissionGranted)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Notification permission is off. Reminders may not appear.',
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickReminderTime,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Change reminder time'),
                  ),
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
                Text('Breakdown reflections view', style: textTheme.titleMedium),
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
                  selected: {_reflectionView},
                  onSelectionChanged: (selection) {
                    _setReflectionView(selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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

  String _formatDay(DateTime date) {
    final month = _monthNames[date.month - 1];
    return '${date.day} $month ${date.year}';
  }
}

class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.text,
    required this.manualWins,
    required this.smartHighlights,
  });

  final String id;
  final DateTime date;
  final String text;
  final List<String> manualWins;
  final List<String> smartHighlights;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'text': text,
    'manualWins': manualWins,
    'smartHighlights': smartHighlights,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      text: json['text'] as String,
      manualWins: (json['manualWins'] as List<dynamic>).cast<String>(),
      smartHighlights: (json['smartHighlights'] as List<dynamic>).cast<String>(),
    );
  }
}

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

class SmartHighlightExtractor {
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

  static List<String> extract({
    required String text,
    required List<String> manualWins,
  }) {
    final candidates = text
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
    final fromText = scored.map((e) => e.key).take(4);

    return {
      ...manualWins.map(_normalize),
      ...fromText,
    }.where((item) => item.isNotEmpty).toList();
  }

  static String _normalize(String input) {
    final clean = input.trim();
    if (clean.isEmpty) {
      return clean;
    }
    return clean[0].toUpperCase() + clean.substring(1);
  }
}

class _StorageKeys {
  static const entries = 'entries_v1';
  static const breakdowns = 'breakdowns_v1';
  static const reminderHour = 'reminder_hour_v1';
  static const reminderMinute = 'reminder_minute_v1';
  static const reminderEnabled = 'reminder_enabled_v1';
  static const reflectionView = 'reflection_view_v1';
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
