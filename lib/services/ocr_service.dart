import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<String> extractTextFromPath(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final StringBuffer buffer = StringBuffer();
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // separate blocks with empty line
    }

    return buffer.toString().trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
