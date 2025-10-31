import 'dart:io';
// ...existing code...
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

Future<Map<String, String>> copyAndThumb(String sourceUri, String itemId) async {
  final uuid = const Uuid().v4();
  final ext = sourceUri.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
  final appDir = await getApplicationDocumentsDirectory();
  final photoDir = Directory('${appDir.path}/photos/$itemId');
  final thumbDir = Directory('${photoDir.path}/thumbs');
  await photoDir.create(recursive: true);
  await thumbDir.create(recursive: true);

  final fileName = '$uuid$ext';
  final destPath = '${photoDir.path}/$fileName';
  final thumbPath = '${thumbDir.path}/$fileName';

  // Copy image
  final srcFile = File(sourceUri.startsWith('file://') ? Uri.parse(sourceUri).toFilePath() : sourceUri);
  await srcFile.copy(destPath);

  // Create thumbnail
  final bytes = await srcFile.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Invalid image');
  final thumb = img.copyResize(decoded, width: decoded.width > decoded.height ? 256 : null, height: decoded.height >= decoded.width ? 256 : null);
  final thumbBytes = ext == '.png' ? img.encodePng(thumb) : img.encodeJpg(thumb, quality: 85);
  await File(thumbPath).writeAsBytes(thumbBytes);

  return {'path': destPath, 'thumbPath': thumbPath};
}
