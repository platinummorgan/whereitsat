import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  test('App documents directory is accessible', () async {
    final dir = await getApplicationDocumentsDirectory();
    expect(dir, isNotNull);
    expect(Directory(dir.path).existsSync(), true);
  });
}
