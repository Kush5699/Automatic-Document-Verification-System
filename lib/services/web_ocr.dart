import 'dart:js_interop';
import 'dart:convert';
import 'dart:typed_data';

/// Calls the global tesseractOCR() JavaScript function defined in index.html
@JS('tesseractOCR')
external JSPromise<JSString> _tesseractOCR(JSString base64Image);

/// Run Tesseract.js OCR on image bytes in the browser
/// Returns the extracted text string
Future<String> runWebOcr(Uint8List imageBytes) async {
  final base64 = base64Encode(imageBytes);
  final result = await _tesseractOCR(base64.toJS).toDart;
  return result.toDart;
}
