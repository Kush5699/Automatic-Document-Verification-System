import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/identity_data.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  final String apiKey;

  GroqService({required this.apiKey});

  // ── Mobile: Extract from OCR text using text LLM ──
  Future<IdentityData> extractEntities(String ocrText) async {
    final prompt = '''You are an expert at extracting structured information from identity documents.
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
- Return ONLY the JSON, no explanation or markdown

OCR Text:
"""
$ocrText
"""''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.1,
        'max_tokens': 500,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final jsonData = jsonDecode(content) as Map<String, dynamic>;
      return IdentityData.fromJson(jsonData);
    } else {
      throw Exception('Groq API error: ${response.statusCode} — ${response.body}');
    }
  }

  // ── Web: Extract directly from image using Groq Vision API ──
  Future<Map<String, dynamic>> extractFromImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Image';

    final prompt = '''You are an expert at reading and extracting structured information from identity document images.
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

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': dataUrl,
                },
              },
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

      // Robust JSON extraction — handles markdown fences, extra text, etc.
      final jsonData = _extractJson(content);
      return jsonData;
    } else {
      throw Exception('Groq Vision API error: ${response.statusCode} — ${response.body}');
    }
  }

  /// Robustly extract JSON from LLM response that may contain markdown fences or extra text
  Map<String, dynamic> _extractJson(String raw) {
    String text = raw.trim();

    // Remove markdown code fences: ```json ... ``` or ``` ... ```
    final fencePattern = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?\s*```');
    final fenceMatch = fencePattern.firstMatch(text);
    if (fenceMatch != null) {
      text = fenceMatch.group(1)!.trim();
    }

    // If still not starting with {, find the first { and last }
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
}
