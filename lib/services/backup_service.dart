import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/breakdown_record.dart';
import '../models/journal_entry.dart';
import '../models/reflection_cache.dart';

class BackupImportData {
  const BackupImportData({
    required this.entries,
    required this.breakdowns,
    required this.reflectionCache,
    required this.settings,
    required this.restoredAudioFiles,
  });

  final List<JournalEntry> entries;
  final List<BreakdownRecord> breakdowns;
  final Map<String, ReflectionCache> reflectionCache;
  final AppSettings settings;
  final int restoredAudioFiles;
}

class BackupService {
  static const int _schemaVersion = 1;
  static const String _backupFolderName = 'LeaveItHere Backups';
  static const List<String> _androidDownloadCandidates = <String>[
    '/storage/emulated/0/Download',
    '/storage/self/primary/Download',
    '/sdcard/Download',
  ];

  Future<String> createBackupFile({
    required List<JournalEntry> entries,
    required List<BreakdownRecord> breakdowns,
    required Map<String, ReflectionCache> reflectionCache,
    required AppSettings settings,
  }) async {
    final audioData = await _collectAudioData(entries);

    final payload = <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'breakdowns': breakdowns.map((item) => item.toJson()).toList(),
      'reflectionCache': reflectionCache.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'settings': _settingsToJson(settings),
      'audioFiles': audioData,
    };

    final encoded = const JsonEncoder.withIndent('  ').convert(payload);
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'leave_it_here_backup_${DateTime.now().millisecondsSinceEpoch}.lihbak';
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(encoded, flush: true);
    return file.path;
  }

  Future<String> saveBackupToDownloads(String backupFilePath) async {
    final sourceFile = File(backupFilePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('Backup file was not found.');
    }

    final targetDir = await _resolveBackupExportDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final safeName = _buildReadableBackupFileName(DateTime.now());

    var targetPath = '${targetDir.path}${Platform.pathSeparator}$safeName';
    var counter = 1;
    while (await File(targetPath).exists()) {
      final dot = safeName.lastIndexOf('.');
      final prefix = dot == -1 ? safeName : safeName.substring(0, dot);
      final ext = dot == -1 ? '' : safeName.substring(dot);
      targetPath = '${targetDir.path}${Platform.pathSeparator}${prefix}_$counter$ext';
      counter += 1;
    }

    final copied = await sourceFile.copy(targetPath);
    return copied.path;
  }

  Future<List<String>> listAvailableBackupFiles() async {
    final candidateDirs = <String>{};

    if (Platform.isAndroid) {
      for (final root in _androidDownloadCandidates) {
        candidateDirs.add('$root${Platform.pathSeparator}$_backupFolderName');
      }
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      candidateDirs.add(
        '${downloadsDir.path}${Platform.pathSeparator}$_backupFolderName',
      );
    }

    final docs = await getApplicationDocumentsDirectory();
    candidateDirs.add('${docs.path}${Platform.pathSeparator}$_backupFolderName');

    final files = <File>[];
    for (final dirPath in candidateDirs) {
      final dir = Directory(dirPath);
      try {
        if (!await dir.exists()) {
          continue;
        }
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) {
            continue;
          }
          final path = entity.path.toLowerCase();
          if (path.endsWith('.lihbak') || path.endsWith('.json')) {
            files.add(entity);
          }
        }
      } catch (_) {
        // Ignore unreadable directories and continue.
      }
    }

    files.sort((a, b) {
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (_) {
        return b.path.compareTo(a.path);
      }
    });

    final unique = <String>[];
    final seen = <String>{};
    for (final file in files) {
      if (seen.add(file.path)) {
        unique.add(file.path);
      }
    }
    return unique;
  }

  Future<Directory> _resolveBackupExportDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = await _resolveWritableAndroidPublicDownloads();
      if (publicDownloads != null) {
        return publicDownloads;
      }
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      return Directory(
        '${downloadsDir.path}${Platform.pathSeparator}$_backupFolderName',
      );
    }

    final docs = await getApplicationDocumentsDirectory();
    return Directory(
      '${docs.path}${Platform.pathSeparator}$_backupFolderName',
    );
  }

  Future<Directory?> _resolveWritableAndroidPublicDownloads() async {
    for (final path in _androidDownloadCandidates) {
      final downloadsRoot = Directory(path);
      final backupDir = Directory(
        '${downloadsRoot.path}${Platform.pathSeparator}$_backupFolderName',
      );

      try {
        if (!await downloadsRoot.exists()) {
          continue;
        }

        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        final probePath =
            '${backupDir.path}${Platform.pathSeparator}.write_probe';
        final probeFile = File(probePath);
        await probeFile.writeAsString('ok', flush: true);
        await probeFile.delete();
        return backupDir;
      } catch (_) {
        // Try next candidate.
      }
    }

    return null;
  }

  String _buildReadableBackupFileName(DateTime now) {
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'leave_it_here_backup_$yyyy-$mm-${dd}_$hh-$min-$ss.lihbak';
  }

  Future<BackupImportData> readBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Backup file was not found.');
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format.');
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > _schemaVersion) {
      throw const FormatException('Unsupported backup version.');
    }

    final entryList = decoded['entries'];
    final breakdownList = decoded['breakdowns'];
    final cacheMap = decoded['reflectionCache'];
    final settingsMap = decoded['settings'];

    if (entryList is! List ||
        breakdownList is! List ||
        cacheMap is! Map ||
        settingsMap is! Map) {
      throw const FormatException('Backup data is incomplete.');
    }

    final entries = entryList
        .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    final breakdowns = breakdownList
        .map((item) => BreakdownRecord.fromJson(item as Map<String, dynamic>))
        .toList();
    final reflectionCache = (cacheMap as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        ReflectionCache.fromJson(value as Map<String, dynamic>),
      ),
    );
    final settings = _settingsFromJson(settingsMap as Map<String, dynamic>);

    final audioFiles = decoded['audioFiles'];
    final restoredEntries = await _restoreAudioPaths(
      entries,
      audioFiles is Map ? audioFiles.cast<String, dynamic>() : const {},
    );

    var restoredAudioFiles = 0;
    for (final entry in restoredEntries) {
      restoredAudioFiles += entry.resolvedAudioPaths.length;
    }

    return BackupImportData(
      entries: restoredEntries,
      breakdowns: breakdowns,
      reflectionCache: reflectionCache,
      settings: settings,
      restoredAudioFiles: restoredAudioFiles,
    );
  }

  Future<Map<String, dynamic>> _collectAudioData(List<JournalEntry> entries) async {
    final out = <String, dynamic>{};
    for (final entry in entries) {
      final paths = entry.resolvedAudioPaths;
      if (paths.isEmpty) {
        continue;
      }

      final durations = entry.resolvedAudioDurations;
      final files = <Map<String, dynamic>>[];
      for (var index = 0; index < paths.length; index += 1) {
        final audioPath = paths[index];
        final file = File(audioPath);
        if (!await file.exists()) {
          continue;
        }

        final extIndex = audioPath.lastIndexOf('.');
        final extension = extIndex == -1
            ? 'm4a'
            : audioPath.substring(extIndex + 1).toLowerCase();
        final bytes = await file.readAsBytes();
        files.add({
          'ext': extension,
          'bytes': base64Encode(bytes),
          'durationMs': index < durations.length ? durations[index] : null,
        });
      }

      if (files.isNotEmpty) {
        out[entry.id] = files;
      }
    }
    return out;
  }

  Future<List<JournalEntry>> _restoreAudioPaths(
    List<JournalEntry> entries,
    Map<String, dynamic> audioFiles,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docs.path}${Platform.pathSeparator}entry_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final restored = <JournalEntry>[];
    for (final entry in entries) {
      final rawAudio = audioFiles[entry.id];
      final normalized = _normalizeAudioItems(rawAudio);
      if (normalized.isEmpty) {
        restored.add(_entryWithAudioPaths(entry, const <String>[], const <int>[]));
        continue;
      }

      final restoredPaths = <String>[];
      final restoredDurations = <int>[];
      for (var index = 0; index < normalized.length; index += 1) {
        final raw = normalized[index];
        final encodedBytes = raw['bytes'];
        if (encodedBytes is! String || encodedBytes.isEmpty) {
          continue;
        }

        final ext = (raw['ext'] as String?)?.trim();
        final extension = (ext == null || ext.isEmpty) ? 'm4a' : ext;
        final filePath =
            '${audioDir.path}${Platform.pathSeparator}imported_${entry.id}_$index.$extension';

        try {
          final bytes = base64Decode(encodedBytes);
          await File(filePath).writeAsBytes(bytes, flush: true);
          restoredPaths.add(filePath);
          final duration = raw['durationMs'];
          if (duration is int) {
            restoredDurations.add(duration);
          }
        } catch (_) {
          // Skip broken clip but continue restoring other clips.
        }
      }

      restored.add(_entryWithAudioPaths(entry, restoredPaths, restoredDurations));
    }

    return restored;
  }

  List<Map<String, dynamic>> _normalizeAudioItems(dynamic rawAudio) {
    if (rawAudio is Map<String, dynamic>) {
      return [rawAudio];
    }
    if (rawAudio is List) {
      return rawAudio.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  JournalEntry _entryWithAudioPaths(
    JournalEntry source,
    List<String> audioPaths,
    List<int> audioDurationMsList,
  ) {
    return JournalEntry(
      id: source.id,
      date: source.date,
      text: source.text,
      manualWins: source.manualWins,
      smartHighlights: source.smartHighlights,
      isBreakdownEntry: source.isBreakdownEntry,
      isPermanentlyLocked: source.isPermanentlyLocked,
      breakdownRecordId: source.breakdownRecordId,
      audioPath: audioPaths.isEmpty ? null : audioPaths.first,
      audioDurationMs: audioDurationMsList.isEmpty ? null : audioDurationMsList.first,
      audioPaths: audioPaths,
      audioDurationMsList: audioDurationMsList,
      transcript: source.transcript,
    );
  }

  Map<String, dynamic> _settingsToJson(AppSettings settings) {
    return {
      'dailyReminderEnabled': settings.dailyReminderEnabled,
      'reminderHour': settings.reminderHour,
      'reminderMinute': settings.reminderMinute,
      'reflectionView': settings.reflectionView.name,
      'winsPerBreakdown': settings.winsPerBreakdown,
      'themeMode': settings.themeMode.name,
      'lockEnabled': settings.lockEnabled,
      'biometricEnabled': settings.biometricEnabled,
      'lockTimeoutMinutes': settings.lockTimeoutMinutes,
      'entryViewMode': settings.entryViewMode.name,
      'hasCompletedTutorial': settings.hasCompletedTutorial,
    };
  }

  AppSettings _settingsFromJson(Map<String, dynamic> json) {
    final reflectionView = json['reflectionView'] as String?;
    final themeMode = json['themeMode'] as String?;
    final entryViewMode = json['entryViewMode'] as String?;

    return AppSettings(
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? true,
      reminderHour: json['reminderHour'] as int? ?? 21,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
      reflectionView: ReflectionView.values.firstWhere(
        (it) => it.name == reflectionView,
        orElse: () => ReflectionView.dropdown,
      ),
      winsPerBreakdown: json['winsPerBreakdown'] as int? ?? 5,
      themeMode: AppThemeMode.values.firstWhere(
        (it) => it.name == themeMode,
        orElse: () => AppThemeMode.light,
      ),
      lockEnabled: json['lockEnabled'] as bool? ?? false,
      biometricEnabled: json['biometricEnabled'] as bool? ?? true,
      lockTimeoutMinutes: json['lockTimeoutMinutes'] as int? ?? 5,
      entryViewMode: EntryViewMode.values.firstWhere(
        (it) => it.name == entryViewMode,
        orElse: () => EntryViewMode.grid,
      ),
      hasCompletedTutorial: json['hasCompletedTutorial'] as bool? ?? false,
    );
  }
}