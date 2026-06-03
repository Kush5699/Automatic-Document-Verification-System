/// Stub for web platform — OCR is not used on web (Groq Vision handles it)
class OcrService {
  Future<String> extractTextFromPath(String imagePath) async {
    throw UnsupportedError('ML Kit OCR is not available on web. Use Groq Vision API instead.');
  }

  void dispose() {}
}
