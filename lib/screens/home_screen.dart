import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_holder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static String groqApiKey = '';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _apiKeyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _apiKeyVisible = false;

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (HomeScreen.groqApiKey.isEmpty) {
      _showApiKeyError();
      return;
    }
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      // Read bytes for web compatibility
      final bytes = await image.readAsBytes();
      ImageHolder.imageBytes = bytes;
      ImageHolder.imagePath = image.path;
      Navigator.pushNamed(context, '/result');
    }
  }

  void _openCamera() {
    if (HomeScreen.groqApiKey.isEmpty) {
      _showApiKeyError();
      return;
    }
    if (kIsWeb) {
      // On web, use image_picker's camera source (browser camera)
      _pickImage(ImageSource.camera);
    } else {
      // On mobile, use the dedicated camera screen
      Navigator.pushNamed(context, '/camera');
    }
  }

  void _showApiKeyError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please enter your Groq API key first'),
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
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0A0E21),
              Color(0xFF000510),
            ],
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
                      const SizedBox(height: 20),
                      // App Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                        ).createShader(bounds),
                        child: const Text(
                          'ID Scanner',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Automatic Identity Card Verification',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scan or upload any identity card to extract guest details automatically using AI.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Platform badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kIsWeb
                              ? const Color(0xFF00D2FF).withValues(alpha: 0.15)
                              : const Color(0xFF6C63FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              kIsWeb ? Icons.language_rounded : Icons.phone_android_rounded,
                              color: kIsWeb ? const Color(0xFF00D2FF) : const Color(0xFF6C63FF),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              kIsWeb ? 'Web Mode — Groq Vision API' : 'Mobile Mode — ML Kit + Groq',
                              style: TextStyle(
                                color: kIsWeb ? const Color(0xFF00D2FF) : const Color(0xFF6C63FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // API Key Input
                      Container(
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
                                const Text(
                                  'Groq API Key',
                                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
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
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _apiKeyVisible ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Color(0xFF00D2FF), size: 20),
                                      onPressed: () {
                                        HomeScreen.groqApiKey = _apiKeyController.text.trim();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('API key saved ✓'),
                                            backgroundColor: Colors.green.shade700,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              onChanged: (val) => HomeScreen.groqApiKey = val.trim(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Scan Options
                      const Text(
                        'SCAN OPTIONS',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Live Scan Card
                      _buildOptionCard(
                        icon: Icons.camera_alt_rounded,
                        title: 'Live Scan',
                        subtitle: kIsWeb
                            ? 'Use your browser camera to capture an ID card'
                            : 'Use your camera to scan an ID card in real-time',
                        gradient: const [Color(0xFF6C63FF), Color(0xFF5A54E0)],
                        onTap: _openCamera,
                      ),
                      const SizedBox(height: 16),
                      // Upload Card
                      _buildOptionCard(
                        icon: Icons.upload_file_rounded,
                        title: 'Upload Image',
                        subtitle: 'Select an ID card image from your gallery',
                        gradient: const [Color(0xFF00D2FF), Color(0xFF0099CC)],
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      const SizedBox(height: 32),
                      // Footer info
                      Center(
                        child: Text(
                          kIsWeb
                              ? 'Powered by Groq Vision AI (Llama 4 Scout 17B)'
                              : 'Powered by Google ML Kit + Groq AI',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
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

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                gradient[0].withValues(alpha: 0.15),
                gradient[1].withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: gradient[0].withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
