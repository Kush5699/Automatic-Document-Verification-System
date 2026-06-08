import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/identity_data.dart';

/// Backend mode: smart (regex, no AI), local (Ollama), or cloud (Groq)
enum LlmBackend { smart, yolo, ollama, groq }

class LlmService {
  final LlmBackend backend;
  final String apiKey; // Only needed for Groq
  final String ollamaUrl; // Default: http://localhost:11434
  final String ollamaModel; // Default: gemma3:4b

  LlmService({
    required this.backend,
    this.apiKey = '',
    this.ollamaUrl = 'http://localhost:11434',
    this.ollamaModel = 'gemma3:4b',
  });

  String get _completionsUrl {
    switch (backend) {
      case LlmBackend.groq:
        return 'https://api.groq.com/openai/v1/chat/completions';
      case LlmBackend.ollama:
        return '$ollamaUrl/api/chat';
      case LlmBackend.smart:
        throw StateError('Smart mode does not use LLM API');
      case LlmBackend.yolo:
        throw StateError('YOLO mode uses Python backend, not LLM API');
    }
  }

  String get _textModel {
    switch (backend) {
      case LlmBackend.groq:
        return 'llama-3.3-70b-versatile';
      case LlmBackend.ollama:
        return ollamaModel;
      case LlmBackend.smart:
        throw StateError('Smart mode does not use LLM API');
      case LlmBackend.yolo:
        throw StateError('YOLO mode uses Python backend, not LLM API');
    }
  }

  String get _visionModel {
    switch (backend) {
      case LlmBackend.groq:
        return 'meta-llama/llama-4-scout-17b-16e-instruct';
      case LlmBackend.ollama:
        return ollamaModel;
      case LlmBackend.smart:
        throw StateError('Smart mode does not use LLM API');
      case LlmBackend.yolo:
        throw StateError('YOLO mode uses Python backend, not LLM API');
    }
  }

  /// Check if the current Ollama model supports vision/multimodal
  bool get supportsVision {
    if (backend == LlmBackend.groq) return true; // Groq vision models always support it
    // Models that support vision
    final visionModels = ['gemma3:4b', 'gemma3:12b', 'gemma3:27b', 'llava:7b', 'llava:13b'];
    return visionModels.contains(ollamaModel);
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (backend == LlmBackend.groq) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  // ═══════════════════════════════════════════════════════
  //  TEXT EXTRACTION (Mobile: OCR text → structured JSON)
  // ═══════════════════════════════════════════════════════

  static const String _textPrompt = '''You are an expert at extracting structured information from identity documents.
I will give you raw OCR text extracted from an identity card (could be a driving license, passport, national ID, etc. from ANY country).

Extract the following fields and return ONLY a valid JSON object. If a field is not found, set it to null.

{
  "first_name": "...",
  "last_name": "...",
  "date_of_birth": "...",
  "gender": "...",
  "address": "...",
  "city": "...",
  "state": "...",
  "postal_code": "...",
  "country": "...",
  "id_number": "...",
  "id_type": "...",
  "expiry_date": "...",
  "nationality": "..."
}

Rules:
- id_type should be one of: "Driving License", "Passport", "National ID", "Voter ID", "Other"
- Dates should be in DD/MM/YYYY format when possible
- For names, capitalize properly (e.g., "John Smith" not "JOHN SMITH")
- Return ONLY the JSON, no explanation or markdown''';

  Future<IdentityData> extractEntities(String ocrText) async {
    final prompt = '$_textPrompt\n\nOCR Text:\n"""\n$ocrText\n"""';

    if (backend == LlmBackend.ollama) {
      return _ollamaTextExtract(prompt);
    } else {
      return _groqTextExtract(prompt);
    }
  }

  Future<IdentityData> _groqTextExtract(String prompt) async {
    final response = await http.post(
      Uri.parse(_completionsUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _textModel,
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.1,
        'max_tokens': 500,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final jsonData = _extractJson(content);
      return IdentityData.fromJson(jsonData);
    } else {
      throw Exception('Groq API error: ${response.statusCode} — ${response.body}');
    }
  }

  Future<IdentityData> _ollamaTextExtract(String prompt) async {
    final response = await http.post(
      Uri.parse(_completionsUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _textModel,
        'messages': [{'role': 'user', 'content': prompt}],
        'stream': false,
        'options': {'temperature': 0.1},
        'format': 'json',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['message']['content'] as String;
      final jsonData = _extractJson(content);
      return IdentityData.fromJson(jsonData);
    } else {
      throw Exception('Ollama error: ${response.statusCode} — ${response.body}');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  VISION EXTRACTION (Web: image → raw text + fields)
  // ═══════════════════════════════════════════════════════

  static const String _visionPrompt = '''You are an expert at reading and extracting structured information from identity document images.
Look at this identity card image (could be a driving license, passport, national ID, etc. from ANY country).

Return a JSON object with exactly these two keys:

{
  "raw_text": "All visible text on the card, written line by line separated by newlines. Include every piece of text you can see.",
  "extracted": {
    "first_name": "...",
    "last_name": "...",
    "date_of_birth": "...",
    "gender": "...",
    "address": "...",
    "city": "...",
    "state": "...",
    "postal_code": "...",
    "country": "...",
    "id_number": "...",
    "id_type": "...",
    "expiry_date": "...",
    "nationality": "..."
  }
}

Rules:
- "raw_text" must contain ALL text visible on the card, line by line
- id_type should be one of: "Driving License", "Passport", "National ID", "Voter ID", "Other"
- Dates should be in DD/MM/YYYY format when possible
- For names, capitalize properly (e.g., "John Smith" not "JOHN SMITH")
- If a field is not found, set it to null
- Return ONLY the JSON, no explanation or markdown''';

  Future<Map<String, dynamic>> extractFromImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    if (backend == LlmBackend.ollama) {
      return _ollamaVisionExtract(base64Image);
    } else {
      return _groqVisionExtract(base64Image);
    }
  }

  Future<Map<String, dynamic>> _groqVisionExtract(String base64Image) async {
    final dataUrl = 'data:image/jpeg;base64,$base64Image';

    final response = await http.post(
      Uri.parse(_completionsUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _visionPrompt},
              {'type': 'image_url', 'image_url': {'url': dataUrl}},
            ],
          }
        ],
        'temperature': 0.1,
        'max_tokens': 1000,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      return _extractJson(content);
    } else {
      throw Exception('Groq Vision API error: ${response.statusCode} — ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _ollamaVisionExtract(String base64Image) async {
    final response = await http.post(
      Uri.parse(_completionsUrl),
      headers: _headers,
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'user',
            'content': _visionPrompt,
            'images': [base64Image], // Ollama uses 'images' array for vision
          }
        ],
        'stream': false,
        'options': {'temperature': 0.1},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['message']['content'] as String;
      return _extractJson(content);
    } else {
      throw Exception('Ollama Vision error: ${response.statusCode} — ${response.body}');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  JSON PARSER (robust — handles markdown fences)
  // ═══════════════════════════════════════════════════════

  Map<String, dynamic> _extractJson(String raw) {
    String text = raw.trim();

    // Remove markdown code fences
    final fencePattern = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?\s*```');
    final fenceMatch = fencePattern.firstMatch(text);
    if (fenceMatch != null) {
      text = fenceMatch.group(1)!.trim();
    }

    // Find first { and last }
    if (!text.startsWith('{')) {
      final firstBrace = text.indexOf('{');
      final lastBrace = text.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        text = text.substring(firstBrace, lastBrace + 1);
      }
    }

    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException(
        'Failed to parse AI response as JSON.\nRaw response:\n${raw.substring(0, raw.length > 500 ? 500 : raw.length)}',
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  //  OLLAMA HEALTH CHECK
  // ═══════════════════════════════════════════════════════

  /// Check if Ollama is running and the model is available
  static Future<Map<String, dynamic>> checkOllamaStatus({
    String url = 'http://localhost:11434',
    String model = 'gemma3:4b',
  }) async {
    try {
      // Check if Ollama is running
      final pingResponse = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (pingResponse.statusCode != 200) {
        return {'running': false, 'modelReady': false, 'error': 'Ollama not responding'};
      }

      // Check if model is available
      final tagsResponse = await http.get(Uri.parse('$url/api/tags'))
          .timeout(const Duration(seconds: 3));
      if (tagsResponse.statusCode == 200) {
        final data = jsonDecode(tagsResponse.body);
        final models = (data['models'] as List?)?.map((m) => m['name'] as String).toList() ?? [];
        final modelReady = models.any((m) => m.startsWith(model.split(':').first));
        return {
          'running': true,
          'modelReady': modelReady,
          'models': models,
          'error': modelReady ? null : 'Model "$model" not found. Run: ollama pull $model',
        };
      }

      return {'running': true, 'modelReady': false, 'error': 'Could not check models'};
    } catch (e) {
      return {'running': false, 'modelReady': false, 'error': 'Ollama not running. Start it first.'};
    }
  }
}
