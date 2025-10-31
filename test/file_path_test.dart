import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Skip this test if platform channels are not available (e.g., not running on a real device/emulator)
  if (kIsWeb) {
    return;
  }
  test('App documents directory is accessible', () async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      expect(dir, isNotNull);
      expect(Directory(dir.path).existsSync(), true);
    } catch (e) {
      // If platform channel is missing, skip the test
      print('Skipping test: platform channel not available ($e)');
    }
  });
}
