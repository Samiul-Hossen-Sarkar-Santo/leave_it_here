import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/breakdown_record.dart';
import '../models/journal_entry.dart';
import '../models/reflection_cache.dart';
import '../services/extraction_service.dart';
import '../services/lock_service.dart';
import '../services/storage_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required StorageService storage,
    required ExtractionService extraction,
    required LockService lock,
  }) : _storage = storage,
       _extraction = extraction,
       _lock = lock;

  final StorageService _storage;
  final ExtractionService _extraction;
  final LockService _lock;

  bool _loading = true;
  bool _locked = false;
  bool _biometricAvailable = false;
  DateTime? _pausedAt;

  int selectedTab = 0;
  DateTime calendarFocusedDay = DateTime.now();
  DateTime? calendarSelectedDay;

  List<JournalEntry> entries = [];
  List<BreakdownRecord> breakdowns = [];
  Map<String, ReflectionCache> reflectionCache = {};
  AppSettings settings = AppSettings.defaults;

  bool get isLoading => _loading;
  bool get isLocked => _locked;
  bool get biometricAvailable => _biometricAvailable;

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Future<void> initialize() async {
    await _initNotifications();
    entries = await _storage.loadEntries();
    entries.sort((a, b) => b.date.compareTo(a.date));

    breakdowns = await _storage.loadBreakdowns();
    breakdowns.sort((a, b) => b.date.compareTo(a.date));

    reflectionCache = await _storage.loadReflectionCache();
    settings = await _storage.loadSettings();

    _biometricAvailable = await _lock.canUseBiometric();
    _loading = false;
    _locked = settings.lockEnabled;

    if (settings.dailyReminderEnabled) {
      await _scheduleDailyReminder();
    }

    notifyListeners();
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

    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> addJournalEntry({
    required String journalText,
    required String manualWinsMultiline,
  }) async {
    final text = journalText.trim();
    if (text.isEmpty) {
      return;
    }

    final manualWins = manualWinsMultiline
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final smartHighlights = await _extraction.extractJournalWins(
      journalText: text,
      manualWins: manualWins,
    );

    final entry = JournalEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      text: text,
      manualWins: manualWins,
      smartHighlights: smartHighlights,
    );

    entries = [entry, ...entries]..sort((a, b) => b.date.compareTo(a.date));
    await _storage.saveEntries(entries);

    await _saveReflectionCache({});
    notifyListeners();
  }

  Future<void> addBreakdownNow({required String note}) async {
    final record = BreakdownRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      note: note.trim(),
    );

    breakdowns = [record, ...breakdowns]..sort((a, b) => b.date.compareTo(a.date));
    await _storage.saveBreakdowns(breakdowns);
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await _storage.saveSettings(settings);

    if (settings.dailyReminderEnabled) {
      await _scheduleDailyReminder();
    } else {
      await AwesomeNotifications().cancel(101);
    }

    notifyListeners();
  }

  Future<void> _scheduleDailyReminder() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 101,
        channelKey: 'daily_journal_reminder',
        title: 'A gentle check-in',
        body: 'Log one good thing you did today 🌿',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
        second: 0,
        repeats: true,
        preciseAlarm: true,
        allowWhileIdle: true,
      ),
    );
  }

  String get journalWatermark {
    if (entries.isEmpty) {
      return 'empty';
    }
    return '${entries.first.date.microsecondsSinceEpoch}_${entries.length}';
  }

  Future<List<String>> getBreakdownHighlights(BreakdownRecord record) async {
    final cached = reflectionCache[record.id];
    if (cached != null &&
        cached.journalWatermark == journalWatermark &&
        cached.winsPerBreakdown == settings.winsPerBreakdown) {
      return cached.highlights;
    }

    final ascending = [...breakdowns]..sort((a, b) => a.date.compareTo(b.date));
    final selectedIndex = ascending.indexWhere((item) => item.id == record.id);

    DateTime? previous;
    if (selectedIndex > 0) {
      previous = ascending[selectedIndex - 1].date;
    }

    final inWindow = entries.where((entry) {
      final afterPrevious = previous == null || entry.date.isAfter(previous);
      final untilCurrent = entry.date.isBefore(record.date) ||
          entry.date.isAtSameMomentAs(record.date);
      return afterPrevious && untilCurrent;
    }).toList();

    final generated = await _extraction.summarizeBreakdownWindow(
      selectedBreakdown: record,
      previousBreakdownDate: previous,
      windowEntries: inWindow,
      maxHighlights: settings.winsPerBreakdown,
    );

    reflectionCache[record.id] = ReflectionCache(
      breakdownId: record.id,
      highlights: generated,
      journalWatermark: journalWatermark,
      winsPerBreakdown: settings.winsPerBreakdown,
    );

    await _saveReflectionCache(reflectionCache);
    return generated;
  }

  Future<void> _saveReflectionCache(Map<String, ReflectionCache> cache) async {
    reflectionCache = cache;
    await _storage.saveReflectionCache(reflectionCache);
  }

  List<BreakdownRecord> breakdownsOnDay(DateTime day) {
    return breakdowns
        .where(
          (record) =>
              record.date.year == day.year &&
              record.date.month == day.month &&
              record.date.day == day.day,
        )
        .toList();
  }

  bool hasBreakdownOnDay(DateTime day) => breakdownsOnDay(day).isNotEmpty;

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _lock.verifyPin(pin);
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    final ok = await _lock.authenticateBiometric();
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  Future<void> setPin(String pin) async {
    await _lock.setPin(pin);
  }

  Future<bool> hasPin() => _lock.hasPin();

  void onPaused() {
    _pausedAt = DateTime.now();
  }

  void onResumed() {
    if (!settings.lockEnabled || _pausedAt == null) {
      return;
    }
    final mins = DateTime.now().difference(_pausedAt!).inMinutes;
    if (mins >= settings.lockTimeoutMinutes) {
      _locked = true;
      notifyListeners();
    }
  }
}
