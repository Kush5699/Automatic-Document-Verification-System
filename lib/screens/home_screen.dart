import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_holder.dart';
import '../services/llm_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Global config
  static String groqApiKey = '';
  static LlmBackend backend = LlmBackend.smart; // Default to Smart (fastest, private)
  static String ollamaUrl = 'http://localhost:11434';
  static String ollamaModel = 'gemma3:4b';
  static String yoloUrl = 'http://localhost:8000';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _ollamaUrlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _apiKeyVisible = false;

  // Ollama status
  bool _checkingOllama = false;
  bool _ollamaRunning = false;
  bool _ollamaModelReady = false;
  String? _ollamaError;
  List<String> _ollamaModels = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _apiKeyController.text = HomeScreen.groqApiKey;
    _ollamaUrlController.text = HomeScreen.ollamaUrl;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _apiKeyController.dispose();
    _ollamaUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkOllamaStatus() async {
    setState(() => _checkingOllama = true);
    final status = await LlmService.checkOllamaStatus(
      url: HomeScreen.ollamaUrl,
      model: HomeScreen.ollamaModel,
    );
    if (mounted) {
      setState(() {
        _checkingOllama = false;
        _ollamaRunning = status['running'] as bool;
        _ollamaModelReady = status['modelReady'] as bool;
        _ollamaError = status['error'] as String?;
        _ollamaModels = (status['models'] as List<String>?) ?? [];
      });
    }
  }

  bool get _isReady {
    switch (HomeScreen.backend) {
      case LlmBackend.smart:
        return true; // Always ready — no setup needed!
      case LlmBackend.yolo:
        return true; // Backend check happens at extraction time
      case LlmBackend.groq:
        return HomeScreen.groqApiKey.isNotEmpty;
      case LlmBackend.ollama:
        return _ollamaRunning && _ollamaModelReady;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isReady) {
      _showNotReadyError();
      return;
    }
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 90);
    if (image != null && mounted) {
      final bytes = await image.readAsBytes();
      ImageHolder.imageBytes = bytes;
      ImageHolder.imagePath = image.path;
      Navigator.pushNamed(context, '/result');
    }
  }

  void _openCamera() {
    if (!_isReady) {
      _showNotReadyError();
      return;
    }
    if (kIsWeb) {
      _pickImage(ImageSource.camera);
    } else {
      Navigator.pushNamed(context, '/camera');
    }
  }

  void _showNotReadyError() {
    final msg = HomeScreen.backend == LlmBackend.groq
        ? 'Please enter your Groq API key first'
        : HomeScreen.backend == LlmBackend.ollama
            ? 'Ollama is not ready. Check connection and model.'
            : 'Not ready';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0E21), Color(0xFF000510)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // App Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                        ).createShader(bounds),
                        child: const Text(
                          'ID Scanner',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Automatic Identity Card Verification',
                        style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)),
                      ),

                      const SizedBox(height: 20),

                      // ══════════════════════════════════════
                      //  BACKEND TOGGLE: Smart vs Local vs Cloud
                      // ══════════════════════════════════════
                      const Text(
                        'AI BACKEND',
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            // Smart (Regex)
                            _buildBackendTab(
                              backend: LlmBackend.smart,
                              icon: Icons.bolt_rounded,
                              label: '⚡ Smart',
                              sublabel: 'Regex · <1s',
                              color: const Color(0xFFFFD600),
                            ),
                            // YOLO
                            _buildBackendTab(
                              backend: LlmBackend.yolo,
                              icon: Icons.center_focus_strong_rounded,
                              label: '🎯 YOLO',
                              sublabel: 'Best accuracy',
                              color: const Color(0xFFFF6D00),
                            ),
                            // Local (Ollama)
                            _buildBackendTab(
                              backend: LlmBackend.ollama,
                              icon: Icons.shield_rounded,
                              label: '🔒 Local',
                              sublabel: 'Ollama',
                              color: const Color(0xFF00C853),
                            ),
                            // Cloud (Groq)
                            _buildBackendTab(
                              backend: LlmBackend.groq,
                              icon: Icons.cloud_rounded,
                              label: '☁️ Cloud',
                              sublabel: 'Groq API',
                              color: const Color(0xFF6C63FF),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ══════════════════════════════════════
                      //  BACKEND CONFIG (conditional)
                      // ══════════════════════════════════════
                      if (HomeScreen.backend == LlmBackend.smart) _buildSmartConfig(),
                      if (HomeScreen.backend == LlmBackend.yolo) _buildYoloConfig(),
                      if (HomeScreen.backend == LlmBackend.ollama) _buildOllamaConfig(),
                      if (HomeScreen.backend == LlmBackend.groq) _buildGroqConfig(),

                      const SizedBox(height: 24),

                      // ══════════════════════════════════════
                      //  SCAN OPTIONS
                      // ══════════════════════════════════════
                      const Text(
                        'SCAN OPTIONS',
                        style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      _buildOptionCard(
                        icon: Icons.camera_alt_rounded,
                        title: 'Live Scan',
                        subtitle: kIsWeb ? 'Use browser camera to capture ID' : 'Scan ID card with your camera',
                        gradient: const [Color(0xFF6C63FF), Color(0xFF5A54E0)],
                        onTap: _openCamera,
                      ),
                      const SizedBox(height: 12),
                      _buildOptionCard(
                        icon: Icons.upload_file_rounded,
                        title: 'Upload Image',
                        subtitle: 'Select an ID card image from your files',
                        gradient: const [Color(0xFF00D2FF), Color(0xFF0099CC)],
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      const SizedBox(height: 24),

                      // Footer
                      Center(
                        child: Text(
                          _footerText,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.25)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _footerText {
    switch (HomeScreen.backend) {
      case LlmBackend.smart:
        return '⚡ Smart Mode — OCR + Regex · <1s · 100% Private · No AI needed';
      case LlmBackend.yolo:
        return '🎯 YOLO Mode — YOLOv8 + EasyOCR · ~95% accuracy · 100% Private';
      case LlmBackend.ollama:
        return '🔒 Local Mode — Data never leaves your machine';
      case LlmBackend.groq:
        return '☁️ Cloud Mode — Powered by Groq API';
    }
  }

  // ── Backend Tab ──
  Widget _buildBackendTab({
    required LlmBackend backend,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    final isSelected = HomeScreen.backend == backend;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => HomeScreen.backend = backend);
          if (backend == LlmBackend.ollama) _checkOllamaStatus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.white30, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white38,
                  fontSize: 11, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  color: isSelected ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.2),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Smart Config Panel ──
  Widget _buildSmartConfig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD600).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00C853),
                  boxShadow: [BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.5), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ready — No setup needed ✓',
                style: TextStyle(color: Color(0xFF00C853), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.bolt_rounded, 'Speed', '< 300ms total (OCR + extraction)'),
          const SizedBox(height: 6),
          _infoRow(Icons.shield_rounded, 'Privacy', '100% on-device, fully offline'),
          const SizedBox(height: 6),
          _infoRow(Icons.code_rounded, 'Engine', 'Regex + Pattern matching + Heuristics'),
          const SizedBox(height: 6),
          _infoRow(Icons.language_rounded, 'Supports', 'US DL, Indian PAN/Aadhaar, Passports'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '💡 No AI model, no API key, no internet — just pure code.\n'
              'OCR extracts text → Regex engine parses fields in milliseconds.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYoloConfig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.center_focus_strong_rounded, color: Color(0xFFFF6D00), size: 20),
              const SizedBox(width: 8),
              const Text('YOLOv8 + EasyOCR Backend', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.bolt_rounded, 'Speed', '~1-2s (GPU) / ~3-5s (CPU)'),
          const SizedBox(height: 6),
          _infoRow(Icons.shield_rounded, 'Privacy', '100% local Python backend'),
          const SizedBox(height: 6),
          _infoRow(Icons.auto_awesome_rounded, 'Accuracy', '~95% for US Driver Licenses'),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.link_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
              const SizedBox(width: 8),
              const Text('Backend URL', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: HomeScreen.yoloUrl),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'http://localhost:8000',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), isDense: true,
            ),
            onChanged: (val) => HomeScreen.yoloUrl = val.trim(),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🎯 YOLOv8 detects field regions → EasyOCR reads each one.\n'
              'Start: cd backend && python main.py',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 15),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // ── Ollama Config Panel ──
  Widget _buildOllamaConfig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _checkingOllama ? Colors.amber
                      : (_ollamaRunning && _ollamaModelReady) ? const Color(0xFF00C853)
                      : Colors.redAccent,
                  boxShadow: [BoxShadow(
                    color: (_ollamaRunning && _ollamaModelReady) ? const Color(0xFF00C853).withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5),
                    blurRadius: 6,
                  )],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _checkingOllama ? 'Checking Ollama...'
                    : (_ollamaRunning && _ollamaModelReady) ? 'Ollama Ready ✓'
                    : _ollamaRunning ? 'Model not found' : 'Ollama not running',
                style: TextStyle(
                  color: (_ollamaRunning && _ollamaModelReady) ? const Color(0xFF00C853) : Colors.redAccent,
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!_checkingOllama)
                GestureDetector(
                  onTap: _checkOllamaStatus,
                  child: Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
                ),
            ],
          ),
          if (_ollamaError != null && !_ollamaModelReady) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(_ollamaError!, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontFamily: 'monospace')),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
              const SizedBox(width: 8),
              const Text('Model', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _buildModelChip('gemma3:1b', '~1GB', false),
              _buildModelChip('gemma3:4b', '~3GB', true),
              _buildModelChip('gemma3:12b', '~8GB', true),
              _buildModelChip('gemma3:27b', '~16GB', true),
              _buildModelChip('llava:7b', '~5GB', true),
            ],
          ),
          if (_ollamaModels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Installed: ${_ollamaModels.join(", ")}', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.link_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
              const SizedBox(width: 8),
              const Text('Ollama URL', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ollamaUrlController,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'http://localhost:11434',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), isDense: true,
            ),
            onChanged: (val) => HomeScreen.ollamaUrl = val.trim(),
            onSubmitted: (_) => _checkOllamaStatus(),
          ),
        ],
      ),
    );
  }

  Widget _buildModelChip(String model, String size, bool hasVision) {
    final isSelected = HomeScreen.ollamaModel == model;
    return GestureDetector(
      onTap: () {
        setState(() => HomeScreen.ollamaModel = model);
        _checkOllamaStatus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C853).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF00C853).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model, style: TextStyle(color: isSelected ? const Color(0xFF00C853) : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(size, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                if (hasVision) ...[const SizedBox(width: 4), Text('👁️', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)))],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Groq Config Panel ──
  Widget _buildGroqConfig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_rounded, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              const Text('Groq API Key', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: !_apiKeyVisible,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'gsk_xxxxxxxxxxxxxxxx',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
              filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: Icon(_apiKeyVisible ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20), onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible)),
                  IconButton(icon: const Icon(Icons.check_circle, color: Color(0xFF00D2FF), size: 20), onPressed: () {
                    HomeScreen.groqApiKey = _apiKeyController.text.trim();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('API key saved ✓'), backgroundColor: Colors.green.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }),
                ],
              ),
            ),
            onChanged: (val) => HomeScreen.groqApiKey = val.trim(),
          ),
          const SizedBox(height: 8),
          Text('⚠️ Data is sent to Groq servers for processing', style: TextStyle(color: Colors.amber.withValues(alpha: 0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOptionCard({required IconData icon, required String title, required String subtitle, required List<Color> gradient, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [gradient[0].withValues(alpha: 0.15), gradient[1].withValues(alpha: 0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: gradient[0].withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
