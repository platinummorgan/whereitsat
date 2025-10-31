import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String _error = '';
  bool _authenticating = false;

  Future<void> _authenticate() async {
    setState(() => _authenticating = true);
    try {
      final didAuth = await auth.authenticate(
        localizedReason: 'Unlock Who Has It',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (didAuth) {
        widget.onUnlock();
      } else {
        setState(() => _error = 'Authentication failed');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _authenticating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64),
            const SizedBox(height: 24),
            _authenticating ? const CircularProgressIndicator() : ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Unlock'),
            ),
            if (_error.isNotEmpty) Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
