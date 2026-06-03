import 'dart:typed_data';

/// Holds image data for passing between screens (works on both mobile and web)
class ImageHolder {
  static Uint8List? imageBytes;
  static String? imagePath;

  static void clear() {
    imageBytes = null;
    imagePath = null;
  }
}
