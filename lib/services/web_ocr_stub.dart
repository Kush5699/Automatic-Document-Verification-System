import 'dart:typed_data';

/// Stub for non-web platforms — never called on mobile
Future<String> runWebOcr(Uint8List imageBytes) async {
  throw UnsupportedError('Web OCR is not available on this platform');
}
