import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/identity_data.dart';
import '../models/image_holder.dart';
import '../services/groq_service.dart';
import 'home_screen.dart';

// Conditional import: real OCR on mobile, stub on web
import '../services/ocr_service.dart' if (dart.library.js_interop) '../services/ocr_service_stub.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  Uint8List? _imageBytes;
  String _rawOcrText = '';
  IdentityData? _identityData;
  bool _isProcessing = true;
  bool _ocrDone = false;
  bool _extractionDone = false;
  String? _errorMessage;
  double _ocrTimeMs = 0;
  double _extractionTimeMs = 0;
  double _totalTimeMs = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController);

    // Get image from holder
    _imageBytes = ImageHolder.imageBytes;

    // Start processing after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processImage();
    });
  }

  Future<void> _processImage() async {
    if (_imageBytes == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'No image provided';
      });
      return;
    }

    final totalStopwatch = Stopwatch()..start();

    try {
      if (kIsWeb) {
        // ── Web: Use Groq Vision API directly ──
        setState(() {
          _ocrDone = false;
          _extractionDone = false;
        });

        final groqService = GroqService(apiKey: HomeScreen.groqApiKey);
        final result = await groqService.extractFromImage(_imageBytes!);
        totalStopwatch.stop();

        if (!mounted) return;

        final rawText = result['raw_text'] as String? ?? 'No text detected';
        final extracted = result['extracted'] as Map<String, dynamic>? ?? {};

        setState(() {
          _rawOcrText = rawText;
          _ocrDone = true;
          _ocrTimeMs = 0; // Vision does it all in one
          _identityData = IdentityData.fromJson(extracted);
          _identityData!.rawOcrText = rawText;
          _identityData!.processingTimeMs =
              totalStopwatch.elapsedMilliseconds.toDouble();
          _extractionDone = true;
          _extractionTimeMs = totalStopwatch.elapsedMilliseconds.toDouble();
          _totalTimeMs = totalStopwatch.elapsedMilliseconds.toDouble();
          _isProcessing = false;
        });
      } else {
        // ── Mobile: ML Kit OCR → Groq text LLM ──
        // Step 1: OCR
        final ocrStopwatch = Stopwatch()..start();
        final ocrService = OcrService();
        final imagePath = ImageHolder.imagePath!;
        final ocrText = await ocrService.extractTextFromPath(imagePath);
        ocrStopwatch.stop();
        ocrService.dispose();

        if (!mounted) return;
        setState(() {
          _rawOcrText = ocrText;
          _ocrDone = true;
          _ocrTimeMs = ocrStopwatch.elapsedMilliseconds.toDouble();
        });

        if (ocrText.trim().isEmpty) {
          setState(() {
            _isProcessing = false;
            _errorMessage =
                'No text detected in the image. Please try again with a clearer image.';
          });
          return;
        }

        // Step 2: Groq Extraction
        final extractionStopwatch = Stopwatch()..start();
        final groqService = GroqService(apiKey: HomeScreen.groqApiKey);
        final identityData = await groqService.extractEntities(ocrText);
        extractionStopwatch.stop();
        totalStopwatch.stop();

        if (!mounted) return;
        setState(() {
          _identityData = identityData;
          _identityData!.rawOcrText = ocrText;
          _identityData!.processingTimeMs =
              totalStopwatch.elapsedMilliseconds.toDouble();
          _extractionDone = true;
          _extractionTimeMs =
              extractionStopwatch.elapsedMilliseconds.toDouble();
          _totalTimeMs = totalStopwatch.elapsedMilliseconds.toDouble();
          _isProcessing = false;
        });
      }

      _pulseController.stop();
    } catch (e) {
      totalStopwatch.stop();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
        _totalTimeMs = totalStopwatch.elapsedMilliseconds.toDouble();
      });
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
          ).createShader(bounds),
          child: const Text(
            'Scan Results',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image Preview ──
                _buildSectionHeader('SCANNED IMAGE', Icons.image_rounded),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.contain,
                          )
                        : const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.white24, size: 48),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Processing Status ──
                if (_isProcessing) _buildProcessingIndicator(),

                // ── Error ──
                if (_errorMessage != null) _buildErrorSection(),

                // ── Timing Stats ──
                if (_ocrDone || _extractionDone) _buildTimingStats(),

                const SizedBox(height: 16),

                // ── Raw OCR Text ──
                if (_ocrDone) _buildRawOcrSection(),

                const SizedBox(height: 20),

                // ── Extracted Fields ──
                if (_extractionDone && _identityData != null)
                  _buildExtractedFieldsSection(),

                const SizedBox(height: 32),

                // ── Action Buttons ──
                if (!_isProcessing) _buildActionButtons(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kIsWeb
                        ? 'Processing with Groq Vision AI...'
                        : _ocrDone
                            ? 'Extracting entities with AI...'
                            : 'Running OCR on image...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kIsWeb
                        ? 'Sending image to Groq Vision for text detection + extraction'
                        : _ocrDone
                            ? 'Sending text to Groq LLM for structured extraction'
                            : 'Google ML Kit is recognizing text on-device',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Processing Error',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: kIsWeb
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeStat(
                    'Vision API',
                    '${_totalTimeMs.toInt()}ms',
                    _extractionDone
                        ? Colors.greenAccent
                        : Colors.white24),
                Container(width: 1, height: 28, color: Colors.white12),
                _buildTimeStat(
                    'Total',
                    '${_totalTimeMs.toInt()}ms',
                    _totalTimeMs > 0 && _totalTimeMs < 2000
                        ? Colors.greenAccent
                        : _totalTimeMs >= 2000
                            ? Colors.orangeAccent
                            : Colors.white24),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeStat('OCR', '${_ocrTimeMs.toInt()}ms',
                    _ocrDone ? Colors.greenAccent : Colors.white24),
                Container(width: 1, height: 28, color: Colors.white12),
                _buildTimeStat(
                    'AI Extract',
                    '${_extractionTimeMs.toInt()}ms',
                    _extractionDone
                        ? Colors.greenAccent
                        : Colors.white24),
                Container(width: 1, height: 28, color: Colors.white12),
                _buildTimeStat(
                    'Total',
                    '${_totalTimeMs.toInt()}ms',
                    _totalTimeMs > 0 && _totalTimeMs < 1000
                        ? Colors.greenAccent
                        : _totalTimeMs >= 1000
                            ? Colors.orangeAccent
                            : Colors.white24),
              ],
            ),
    );
  }

  Widget _buildTimeStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRawOcrSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            kIsWeb ? 'DETECTED TEXT (VISION AI)' : 'RAW OCR OUTPUT',
            Icons.text_fields_rounded),
        const SizedBox(height: 6),
        Text(
          kIsWeb
              ? 'Text detected by Groq Vision AI from the image'
              : 'This is exactly what the OCR detected from the image',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00D2FF).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'DETECTED TEXT',
                      style: TextStyle(
                        color: Color(0xFF00D2FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_rawOcrText.split('\n').where((l) => l.trim().isNotEmpty).length} lines',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              // OCR text with line numbers
              ..._rawOcrText
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final lineNum = entry.key + 1;
                final line = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$lineNum',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          line,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedFieldsSection() {
    final fields = _identityData!.toDisplayMap();
    final filledFields =
        fields.entries.where((e) => e.value != null && e.value!.isNotEmpty);
    final emptyFields =
        fields.entries.where((e) => e.value == null || e.value!.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('EXTRACTED FIELDS', Icons.auto_awesome_rounded),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'AI extracted ${filledFields.length} of ${fields.length} fields',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(filledFields.length / fields.length * 100).toInt()}% filled',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filled Fields
        ...filledFields.map((entry) => _buildFieldTile(
              entry.key,
              entry.value!,
              isFilled: true,
            )),

        // Empty Fields
        if (emptyFields.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'NOT DETECTED',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...emptyFields.map((entry) => _buildFieldTile(
                entry.key,
                'Not detected',
                isFilled: false,
              )),
        ],
      ],
    );
  }

  Widget _buildFieldTile(String label, String value,
      {required bool isFilled}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isFilled
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFilled
              ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFilled
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isFilled ? const Color(0xFF6C63FF) : Colors.white24,
            size: 18,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color:
                    Colors.white.withValues(alpha: isFilled ? 0.5 : 0.25),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isFilled ? Colors.white : Colors.white24,
                fontSize: 14,
                fontWeight: isFilled ? FontWeight.w600 : FontWeight.w400,
                fontStyle: isFilled ? FontStyle.normal : FontStyle.italic,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Scan Another
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              ImageHolder.clear();
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.document_scanner_rounded, size: 20),
                SizedBox(width: 10),
                Text(
                  'Scan Another Card',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Retry
        if (_errorMessage != null)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _isProcessing = true;
                  _errorMessage = null;
                  _ocrDone = false;
                  _extractionDone = false;
                  _rawOcrText = '';
                  _identityData = null;
                });
                _pulseController.repeat(reverse: true);
                _processImage();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.5),
                ),
                foregroundColor: const Color(0xFF00D2FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Retry Processing',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
