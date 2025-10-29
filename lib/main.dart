import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:who_has_it/data/db.dart';
import 'package:who_has_it/ui/home.dart';
import 'package:who_has_it/ui/settings.dart';
import 'package:who_has_it/ui/lock_screen.dart';
import 'package:hive/hive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDb();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _lastPaused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _checkLock() {
    final enabled = Hive.box('settings').get('appLockEnabled', defaultValue: false);
    setState(() => _locked = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPaused = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final enabled = Hive.box('settings').get('appLockEnabled', defaultValue: false);
      if (enabled && _lastPaused != null && DateTime.now().difference(_lastPaused!) > const Duration(minutes: 2)) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _locked
          ? LockScreen(onUnlock: () => setState(() => _locked = false))
          : HomeScreen(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
