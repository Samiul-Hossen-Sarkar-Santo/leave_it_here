enum ReflectionView { dropdown, calendar }

enum AppThemeMode { system, light, dark }

enum EntryViewMode { list, grid }

class AppSettings {
  const AppSettings({
    required this.dailyReminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.reflectionView,
    required this.winsPerBreakdown,
    required this.themeMode,
    required this.lockEnabled,
    required this.biometricEnabled,
    required this.lockTimeoutMinutes,
    required this.entryViewMode,
    required this.hasCompletedTutorial,
  });

  final bool dailyReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final ReflectionView reflectionView;
  final int winsPerBreakdown;
  final AppThemeMode themeMode;
  final bool lockEnabled;
  final bool biometricEnabled;
  final int lockTimeoutMinutes;
  final EntryViewMode entryViewMode;
  final bool hasCompletedTutorial;

  static const defaults = AppSettings(
    dailyReminderEnabled: true,
    reminderHour: 21,
    reminderMinute: 0,
    reflectionView: ReflectionView.dropdown,
    winsPerBreakdown: 5,
    themeMode: AppThemeMode.light,
    lockEnabled: false,
    biometricEnabled: true,
    lockTimeoutMinutes: 5,
    entryViewMode: EntryViewMode.grid,
    hasCompletedTutorial: false,
  );

  AppSettings copyWith({
    bool? dailyReminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    ReflectionView? reflectionView,
    int? winsPerBreakdown,
    AppThemeMode? themeMode,
    bool? lockEnabled,
    bool? biometricEnabled,
    int? lockTimeoutMinutes,
    EntryViewMode? entryViewMode,
    bool? hasCompletedTutorial,
  }) {
    return AppSettings(
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      reflectionView: reflectionView ?? this.reflectionView,
      winsPerBreakdown: winsPerBreakdown ?? this.winsPerBreakdown,
      themeMode: themeMode ?? this.themeMode,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockTimeoutMinutes: lockTimeoutMinutes ?? this.lockTimeoutMinutes,
      entryViewMode: entryViewMode ?? this.entryViewMode,
      hasCompletedTutorial: hasCompletedTutorial ?? this.hasCompletedTutorial,
    );
  }
}
