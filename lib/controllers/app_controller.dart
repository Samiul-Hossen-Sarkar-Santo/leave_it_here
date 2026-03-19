import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/breakdown_record.dart';
import '../models/journal_entry.dart';
import '../models/reflection_cache.dart';
import '../services/backup_service.dart';
import '../services/extraction_service.dart';
import '../services/lock_service.dart';
import '../services/storage_service.dart';
import '../services/voice_entry_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required StorageService storage,
    required ExtractionService extraction,
    required LockService lock,
    required VoiceEntryService voice,
    required BackupService backup,
  }) : _storage = storage,
       _extraction = extraction,
       _lock = lock,
       _voice = voice,
       _backup = backup;

  final StorageService _storage;
  final ExtractionService _extraction;
  final LockService _lock;
  final VoiceEntryService _voice;
  final BackupService _backup;

  bool _loading = true;
  bool _locked = false;
  bool _biometricAvailable = false;
  String _biometricStatus = 'Not checked';
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
  String get biometricStatus => _biometricStatus;

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

    await refreshBiometricAvailability(notify: false);
    _loading = false;
    _locked = settings.lockEnabled;

    if (settings.dailyReminderEnabled) {
      await _scheduleDailyReminder();
    }

    notifyListeners();
  }

  Future<void> refreshBiometricAvailability({bool notify = true}) async {
    _biometricAvailable = await _lock.canUseBiometric();
    _biometricStatus =
        _lock.lastBiometricMessage ??
        (_biometricAvailable ? 'Biometrics ready' : 'Biometrics unavailable');
    if (notify) {
      notifyListeners();
    }
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
    bool isBreakdownEntry = false,
    String? transcript,
    String? audioPath,
    int? audioDurationMs,
    List<String>? audioPaths,
    List<int>? audioDurationMsList,
  }) async {
    await saveEntry(
      journalText: journalText,
      manualWinsMultiline: manualWinsMultiline,
      isBreakdownEntry: isBreakdownEntry,
      transcript: transcript,
      audioPath: audioPath,
      audioDurationMs: audioDurationMs,
      audioPaths: audioPaths,
      audioDurationMsList: audioDurationMsList,
    );
  }

  Future<String?> saveEntry({
    String? entryId,
    required String journalText,
    required String manualWinsMultiline,
    required bool isBreakdownEntry,
    String? transcript,
    String? audioPath,
    int? audioDurationMs,
    List<String>? audioPaths,
    List<int>? audioDurationMsList,
  }) async {
    final initialText = journalText.trim();
    final transcriptTrimmed = transcript?.trim();
    final normalizedAudioPaths = (audioPaths ?? const <String>[])
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (normalizedAudioPaths.isEmpty && audioPath != null && audioPath.trim().isNotEmpty) {
      normalizedAudioPaths.add(audioPath.trim());
    }

    final normalizedAudioDurations = (audioDurationMsList ?? const <int>[])
        .where((item) => item >= 0)
        .toList();
    if (normalizedAudioDurations.isEmpty && audioDurationMs != null && audioDurationMs >= 0) {
      normalizedAudioDurations.add(audioDurationMs);
    }

    final hasAudio = normalizedAudioPaths.isNotEmpty;
    final hasTranscript = transcriptTrimmed != null && transcriptTrimmed.isNotEmpty;
    if (initialText.isEmpty &&
      !hasTranscript &&
        !hasAudio) {
      return null;
    }

    final text = initialText.isEmpty && (hasAudio || hasTranscript)
      ? '[Voice entry]'
      : initialText;

    final existingIndex =
        entryId == null ? -1 : entries.indexWhere((entry) => entry.id == entryId);
    final existing = existingIndex == -1 ? null : entries[existingIndex];
    if (existing?.isPermanentlyLocked == true) {
      return null;
    }

    final manualWins = manualWinsMultiline
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final smartHighlights = await _extraction.extractJournalWins(
      journalText: [text, transcriptTrimmed]
          .whereType<String>()
          .where((it) => it.isNotEmpty)
          .join('\n'),
      manualWins: manualWins,
    );

    var breakdownRecordId = existing?.breakdownRecordId;
    if (isBreakdownEntry && breakdownRecordId == null) {
      final record = BreakdownRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        note: text,
      );
      breakdowns = [record, ...breakdowns]..sort((a, b) => b.date.compareTo(a.date));
      await _storage.saveBreakdowns(breakdowns);
      breakdownRecordId = record.id;
    }

    if (!isBreakdownEntry) {
      breakdownRecordId = null;
    }

    final entry = JournalEntry(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: existing?.date ?? DateTime.now(),
      text: text,
      manualWins: manualWins,
      smartHighlights: smartHighlights,
      isBreakdownEntry: isBreakdownEntry,
      isPermanentlyLocked: existing?.isPermanentlyLocked ?? false,
      breakdownRecordId: breakdownRecordId,
        audioPath: normalizedAudioPaths.isNotEmpty
          ? normalizedAudioPaths.first
          : (existing?.resolvedAudioPaths.isNotEmpty == true
            ? existing!.resolvedAudioPaths.first
            : null),
        audioDurationMs: normalizedAudioDurations.isNotEmpty
          ? normalizedAudioDurations.first
          : (existing?.resolvedAudioDurations.isNotEmpty == true
            ? existing!.resolvedAudioDurations.first
            : null),
        audioPaths: normalizedAudioPaths.isNotEmpty
          ? normalizedAudioPaths
          : (existing?.resolvedAudioPaths ?? const <String>[]),
        audioDurationMsList: normalizedAudioDurations.isNotEmpty
          ? normalizedAudioDurations
          : (existing?.resolvedAudioDurations ?? const <int>[]),
      transcript: transcriptTrimmed ?? existing?.transcript,
    );

    if (existingIndex == -1) {
      entries = [entry, ...entries]..sort((a, b) => b.date.compareTo(a.date));
    } else {
      entries[existingIndex] = entry;
      entries.sort((a, b) => b.date.compareTo(a.date));
    }

    await _storage.saveEntries(entries);
    reflectionCache = {};
    await _storage.saveReflectionCache(reflectionCache);
    notifyListeners();
    return entry.id;
  }

  Future<void> updateEntryWins({
    required String entryId,
    required String manualWinsMultiline,
  }) async {
    final index = entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }

    final current = entries[index];
    final manualWins = manualWinsMultiline
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final smartHighlights = await _extraction.extractJournalWins(
      journalText: current.text,
      manualWins: manualWins,
    );

    if (current.isPermanentlyLocked) {
      return;
    }

    final updated = current.copyWith(
      manualWins: manualWins,
      smartHighlights: smartHighlights,
    );

    entries[index] = updated;
    await _storage.saveEntries(entries);
    reflectionCache = {};
    await _storage.saveReflectionCache(reflectionCache);
    notifyListeners();
  }

  Future<void> addBreakdownNow({required String note}) async {
    await saveEntry(
      journalText: note,
      manualWinsMultiline: '',
      isBreakdownEntry: true,
    );
  }

  Future<void> lockEntryForever(String entryId) async {
    final index = entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return;
    }

    final current = entries[index];
    if (current.isPermanentlyLocked) {
      return;
    }

    entries[index] = current.copyWith(isPermanentlyLocked: true);
    await _storage.saveEntries(entries);
    notifyListeners();
  }

  Future<void> completeTutorial() async {
    if (settings.hasCompletedTutorial) {
      return;
    }
    settings = settings.copyWith(hasCompletedTutorial: true);
    await _storage.saveSettings(settings);
    notifyListeners();
  }

  Future<void> updateBreakdownNote({
    required String breakdownId,
    required String note,
  }) async {
    final index = breakdowns.indexWhere((item) => item.id == breakdownId);
    if (index == -1) {
      return;
    }

    final current = breakdowns[index];
    breakdowns[index] = BreakdownRecord(
      id: current.id,
      date: current.date,
      note: note.trim(),
    );

    await _storage.saveBreakdowns(breakdowns);
    notifyListeners();
  }

  Future<bool> startVoiceCapture({
    void Function(String transcript)? onTranscript,
  }) {
    return _voice.startCapture(onTranscript: onTranscript);
  }

  Future<VoiceCaptureResult?> stopVoiceCapture() {
    return _voice.stopCapture();
  }

  Future<bool> pauseVoiceCapture() {
    return _voice.pauseCapture();
  }

  Future<bool> resumeVoiceCapture() {
    return _voice.resumeCapture();
  }

  Future<void> cancelVoiceCapture() {
    return _voice.cancelCapture();
  }

  List<JournalEntry> get sortedEntries {
    final out = [...entries];
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  JournalEntry? getEntryById(String entryId) {
    final index = entries.indexWhere((entry) => entry.id == entryId);
    if (index == -1) {
      return null;
    }
    return entries[index];
  }

  JournalEntry? findEntryForBreakdown(String breakdownId) {
    for (final entry in entries) {
      if (entry.breakdownRecordId == breakdownId) {
        return entry;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
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

  Future<String> exportBackupFile() {
    return _backup.createBackupFile(
      entries: entries,
      breakdowns: breakdowns,
      reflectionCache: reflectionCache,
      settings: settings,
    );
  }

  Future<String> exportBackupToDownloads() async {
    final tempBackupPath = await exportBackupFile();
    return _backup.saveBackupToDownloads(tempBackupPath);
  }

  Future<List<String>> listAvailableBackupFiles() {
    return _backup.listAvailableBackupFiles();
  }

  Future<int> importBackupFile(String filePath) async {
    final imported = await _backup.readBackupFile(filePath);

    final normalizedSettings = imported.settings.copyWith(
      lockEnabled: false,
      biometricEnabled: false,
    );

    entries = [...imported.entries]..sort((a, b) => b.date.compareTo(a.date));
    breakdowns = [...imported.breakdowns]..sort((a, b) => b.date.compareTo(a.date));
    reflectionCache = imported.reflectionCache;
    settings = normalizedSettings;

    await _storage.saveEntries(entries);
    await _storage.saveBreakdowns(breakdowns);
    await _storage.saveReflectionCache(reflectionCache);
    await _storage.saveSettings(settings);

    if (settings.dailyReminderEnabled) {
      await _scheduleDailyReminder();
    } else {
      await AwesomeNotifications().cancel(101);
    }

    _locked = false;
    notifyListeners();
    return imported.restoredAudioFiles;
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
    final ascending = [...breakdowns]..sort((a, b) => a.date.compareTo(b.date));
    final selectedIndex = ascending.indexWhere((item) => item.id == record.id);

    DateTime? previous;
    if (selectedIndex > 0) {
      previous = ascending[selectedIndex - 1].date;
    }

    final inWindow = entries.where((entry) {
      final afterPrevious = previous == null || entry.date.isAfter(previous);
      final untilCurrent =
          entry.date.isBefore(record.date) ||
          entry.date.isAtSameMomentAs(record.date);
      return afterPrevious && untilCurrent;
    }).toList();

    final windowWatermark = _watermarkForEntries(inWindow);
    final cached = reflectionCache[record.id];
    if (cached != null &&
        cached.journalWatermark == windowWatermark &&
        cached.winsPerBreakdown == settings.winsPerBreakdown) {
      return cached.highlights;
    }

    final generated = await _extraction.summarizeBreakdownWindow(
      selectedBreakdown: record,
      previousBreakdownDate: previous,
      windowEntries: inWindow,
      maxHighlights: settings.winsPerBreakdown,
    );

    reflectionCache[record.id] = ReflectionCache(
      breakdownId: record.id,
      highlights: generated,
      journalWatermark: windowWatermark,
      winsPerBreakdown: settings.winsPerBreakdown,
    );

    await _saveReflectionCache(reflectionCache);
    return generated;
  }

  Future<void> _saveReflectionCache(Map<String, ReflectionCache> cache) async {
    reflectionCache = cache;
    await _storage.saveReflectionCache(reflectionCache);
  }

  String _watermarkForEntries(List<JournalEntry> records) {
    if (records.isEmpty) {
      return 'empty_window';
    }

    records.sort((a, b) => b.date.compareTo(a.date));
    return '${records.first.date.microsecondsSinceEpoch}_${records.length}';
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
    if (!_biometricAvailable) {
      await refreshBiometricAvailability();
      return false;
    }

    final ok = await _lock.authenticateBiometric();
    _biometricStatus =
        _lock.lastBiometricMessage ??
        (ok
            ? 'Biometric authentication successful'
            : 'Biometric authentication failed');

    if (ok) {
      _locked = false;
    }
    notifyListeners();
    return ok;
  }

  Future<String?> tryBiometricUnlockWithMessage() async {
    final ok = await unlockWithBiometric();
    if (ok) {
      return null;
    }
    return biometricStatus;
  }

  Future<void> setPin(String pin) async {
    await _lock.setPin(pin);
  }

  Future<bool> verifyPin(String pin) => _lock.verifyPin(pin);

  Future<bool> hasPin() => _lock.hasPin();

  void onPaused() {
    _pausedAt = DateTime.now();
  }

  void onResumed() {
    refreshBiometricAvailability();

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
