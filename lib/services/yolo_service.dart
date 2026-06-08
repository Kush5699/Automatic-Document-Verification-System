import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/identity_data.dart';

/// Service that sends images to the local Python YOLOv8 + EasyOCR backend
class YoloService {
  final String backendUrl;

  YoloService({this.backendUrl = 'http://localhost:8000'});

  /// Check if the Python backend is running
  Future<bool> isHealthy() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Extract fields from an image using YOLOv8 + EasyOCR
  Future<Map<String, dynamic>> extractFromImage(Uint8List imageBytes) async {
    final uri = Uri.parse('$backendUrl/extract');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'id_card.jpg',
    ));

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('YOLO Backend error: ${response.statusCode} — ${response.body}');
    }
  }

  /// Convert YOLO response to IdentityData
  IdentityData toIdentityData(Map<String, dynamic> result) {
    // Parse name into first/last
    String? firstName;
    String? lastName;
    final nameRaw = result['name'] as String?;
    if (nameRaw != null && nameRaw.isNotEmpty) {
      final parts = nameRaw.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        firstName = parts.first;
        lastName = parts.sublist(1).join(' ');
      } else {
        firstName = parts.first;
      }
    }

    return IdentityData(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: result['dob'] as String?,
      gender: result['gender'] as String?,
      address: result['address'] as String?,
      city: null,
      state: result['state'] as String?,
      postalCode: null,
      country: result['state'] != null ? 'United States' : null,
      idNumber: result['id_number'] as String?,
      idType: 'Driving License',
      expiryDate: result['expiry_date'] as String?,
      nationality: null,
      rawOcrText: (result['raw_detections'] as List?)?.map((d) => '${d['field']}: ${d['text']}').join('\n') ?? '',
      processingTimeMs: (result['processing_time_ms'] as num?)?.toDouble() ?? 0,
    );
  }
}
