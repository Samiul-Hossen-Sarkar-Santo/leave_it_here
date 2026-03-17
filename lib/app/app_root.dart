import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../screens/home_screen.dart';
import '../screens/lock_screen.dart';
import '../services/extraction_service.dart';
import '../services/lock_service.dart';
import '../services/storage_service.dart';

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
      extraction: LocalExtractionService(),
      lock: LockService(),
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
      seedColor: const Color(0xFF9AAFA9),
      brightness: Brightness.light,
    ).copyWith(surface: const Color(0xFFF4F7F5));

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9AAFA9),
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
            scaffoldBackgroundColor: const Color(0xFFEEF2EF),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkScheme,
          ),
          home: _controller.isLoading
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _controller.isLocked
              ? LockScreen(
                  onPinUnlock: _controller.unlockWithPin,
                  onBiometricUnlock: _controller.unlockWithBiometric,
                  showBiometric:
                      _controller.settings.biometricEnabled &&
                      _controller.biometricAvailable,
                )
              : HomeScreen(controller: _controller),
        );
      },
    );
  }
}
