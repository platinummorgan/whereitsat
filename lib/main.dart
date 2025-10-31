import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:where_its_at/data/db.dart';
import 'package:where_its_at/data/notifications.dart';
import 'package:where_its_at/ui/home.dart';
import 'package:where_its_at/ui/onboarding.dart';
import 'package:where_its_at/ui/settings.dart';
import 'package:where_its_at/ui/lock_screen.dart';


// ...existing code...

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDb();                       // opens Hive boxes incl. 'settings'
  runApp(const ProviderScope(child: MyApp()));
}


class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _lastPaused;

  Box get _settings => Hive.box('settings');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyInitialLock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initNotifications(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _applyInitialLock() {
    final enabled = _settings.get('appLockEnabled', defaultValue: false) as bool;
    setState(() => _locked = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPaused = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final enabled = _settings.get('appLockEnabled', defaultValue: false) as bool;
      final pausedLongEnough = _lastPaused != null &&
          DateTime.now().difference(_lastPaused!) > const Duration(minutes: 2);
      if (enabled && pausedLongEnough) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingSeen =
        _settings.get('onboardingSeen', defaultValue: false) as bool;
    final themeModeSetting = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      title: "Where It's At",
      home: _locked
          ? LockScreen(
              onUnlock: () {
                if (!mounted) return;
                setState(() => _locked = false);
              },
            )
          : (onboardingSeen
              ? const HomeScreen()
              : OnboardingScreen(
                  onFinish: () {
                    _settings.put('onboardingSeen', true);
                    if (!mounted) return;
                    setState(() {});
                  },
                )),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/onboarding': (_) => OnboardingScreen(
              onFinish: () {
                _settings.put('onboardingSeen', true);
                _navKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C4DFF),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C4DFF),
        brightness: Brightness.dark,
      ),
      themeMode: themeModeFromSetting(themeModeSetting),
    );
  }
}
