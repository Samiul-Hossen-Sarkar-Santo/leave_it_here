import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/breakdown_record.dart';
import '../models/journal_entry.dart';
import '../models/reflection_cache.dart';

class StorageService {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<List<JournalEntry>> loadEntries() async {
    final raw = (await _prefs).getString(_StorageKeys.entries);
    if (raw == null) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<BreakdownRecord>> loadBreakdowns() async {
    final raw = (await _prefs).getString(_StorageKeys.breakdowns);
    if (raw == null) {
      return [];
    }
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => BreakdownRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, ReflectionCache>> loadReflectionCache() async {
    final raw = (await _prefs).getString(_StorageKeys.reflectionCache);
    if (raw == null) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        ReflectionCache.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await _prefs;

    final reflectionRaw =
        prefs.getString(_StorageKeys.reflectionView) ?? ReflectionView.dropdown.name;
    final themeRaw = prefs.getString(_StorageKeys.themeMode) ?? AppThemeMode.light.name;

    return AppSettings(
      dailyReminderEnabled: prefs.getBool(_StorageKeys.reminderEnabled) ?? true,
      reminderHour: prefs.getInt(_StorageKeys.reminderHour) ?? 21,
      reminderMinute: prefs.getInt(_StorageKeys.reminderMinute) ?? 0,
      reflectionView: ReflectionView.values.firstWhere(
        (it) => it.name == reflectionRaw,
        orElse: () => ReflectionView.dropdown,
      ),
      winsPerBreakdown: prefs.getInt(_StorageKeys.winsPerBreakdown) ?? 5,
      themeMode: AppThemeMode.values.firstWhere(
        (it) => it.name == themeRaw,
        orElse: () => AppThemeMode.light,
      ),
      lockEnabled: prefs.getBool(_StorageKeys.lockEnabled) ?? false,
      biometricEnabled: prefs.getBool(_StorageKeys.biometricEnabled) ?? true,
      lockTimeoutMinutes: prefs.getInt(_StorageKeys.lockTimeoutMinutes) ?? 5,
    );
  }

  Future<void> saveEntries(List<JournalEntry> entries) async {
    await (await _prefs).setString(
      _StorageKeys.entries,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveBreakdowns(List<BreakdownRecord> breakdowns) async {
    await (await _prefs).setString(
      _StorageKeys.breakdowns,
      jsonEncode(breakdowns.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveReflectionCache(Map<String, ReflectionCache> cache) async {
    final encoded = cache.map((key, value) => MapEntry(key, value.toJson()));
    await (await _prefs).setString(_StorageKeys.reflectionCache, jsonEncode(encoded));
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await _prefs;
    await prefs.setBool(_StorageKeys.reminderEnabled, settings.dailyReminderEnabled);
    await prefs.setInt(_StorageKeys.reminderHour, settings.reminderHour);
    await prefs.setInt(_StorageKeys.reminderMinute, settings.reminderMinute);
    await prefs.setString(_StorageKeys.reflectionView, settings.reflectionView.name);
    await prefs.setInt(_StorageKeys.winsPerBreakdown, settings.winsPerBreakdown);
    await prefs.setString(_StorageKeys.themeMode, settings.themeMode.name);
    await prefs.setBool(_StorageKeys.lockEnabled, settings.lockEnabled);
    await prefs.setBool(_StorageKeys.biometricEnabled, settings.biometricEnabled);
    await prefs.setInt(_StorageKeys.lockTimeoutMinutes, settings.lockTimeoutMinutes);
  }
}

class _StorageKeys {
  static const entries = 'entries_v2';
  static const breakdowns = 'breakdowns_v2';
  static const reflectionCache = 'reflection_cache_v1';
  static const reminderHour = 'reminder_hour_v2';
  static const reminderMinute = 'reminder_minute_v2';
  static const reminderEnabled = 'reminder_enabled_v2';
  static const reflectionView = 'reflection_view_v2';
  static const winsPerBreakdown = 'wins_per_breakdown_v1';
  static const themeMode = 'theme_mode_v1';
  static const lockEnabled = 'lock_enabled_v1';
  static const biometricEnabled = 'biometric_enabled_v1';
  static const lockTimeoutMinutes = 'lock_timeout_minutes_v1';
}
