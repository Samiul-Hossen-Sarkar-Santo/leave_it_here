import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../screens/home_screen.dart';
import '../screens/lock_screen.dart';
import '../screens/tutorial_screen.dart';
import '../services/backup_service.dart';
import '../services/extraction_service.dart';
import '../services/lock_service.dart';
import '../services/storage_service.dart';
import '../services/voice_entry_service.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AppController(
      storage: StorageService(),
      extraction: HeuristicExtractionService(),
      lock: LockService(),
      voice: VoiceEntryService(),
      backup: BackupService(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.onPaused();
    }
    if (state == AppLifecycleState.resumed) {
      _controller.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    ).copyWith(surface: const Color(0xFFF4F7F5));

    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Leave It Here',
          themeMode: _controller.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            scaffoldBackgroundColor: const Color.fromARGB(255, 235, 239, 235),
          ),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: darkScheme),
          home: _controller.isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _controller.isLocked
              ? LockScreen(
                  onPinUnlock: _controller.unlockWithPin,
                  onBiometricUnlock: _controller.tryBiometricUnlockWithMessage,
                  showBiometric:
                      _controller.settings.biometricEnabled &&
                      _controller.biometricAvailable,
                )
              : HomeScreen(controller: _controller),
          builder: (context, child) {
            if (_controller.isLoading) {
              return child ?? const SizedBox.shrink();
            }

            if (_controller.settings.hasCompletedTutorial) {
              return child ?? const SizedBox.shrink();
            }

            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                TutorialScreen(
                  onDone: _controller.completeTutorial,
                  popOnDone: false,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
