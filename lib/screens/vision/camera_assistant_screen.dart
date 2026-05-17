import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/image_service.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:benw_edu/widgets/benw_markdown.dart';

class CameraAssistantScreen extends StatefulWidget {
  const CameraAssistantScreen({super.key});

  @override
  State<CameraAssistantScreen> createState() => _CameraAssistantScreenState();
}

class _CameraAssistantScreenState extends State<CameraAssistantScreen> {
  final BenwEduService _benwService = BenwEduService();
  final ImageService _imageService = ImageService();
  final TextEditingController _promptController = TextEditingController();
  
  Uint8List? _selectedImage;
  String _response = '';
  bool _isProcessing = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _benwService.init();
    _prepareDemoImage();
  }

  Future<void> _prepareDemoImage() async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        await Permission.manageExternalStorage.request();
      }

      final List<String> assets = [
        'assets/images/math_demo_2.png',
        'assets/images/math_demo_3.png',
      ];
      final List<String> names = [
        'benw_geometry_problem.png',
        'benw_algebra_problem.png',
      ];

      Directory? externalDir;
      if (Platform.isAndroid) {
        // DCIM/Camera is the most aggressively scanned folder
        final List<String> candidates = [
          '/storage/emulated/0/DCIM/Camera',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/Download',
        ];
        
        for (final path in candidates) {
          final dir = Directory(path);
          if (await dir.exists()) {
            externalDir = dir;
            break;
          }
        }
        
        if (externalDir == null) {
          final dirs = await getExternalStorageDirectories(type: StorageDirectory.pictures);
          if (dirs != null && dirs.isNotEmpty) externalDir = dirs.first;
        }
      } else {
        externalDir = await getApplicationDocumentsDirectory();
      }

      if (externalDir != null) {
        for (int i = 0; i < assets.length; i++) {
          final ByteData data = await rootBundle.load(assets[i]);
          final Uint8List bytes = data.buffer.asUint8List();
          final String filePath = '${externalDir.path}/${names[i]}';
          final File file = File(filePath);
          await file.writeAsBytes(bytes);
        }
        setState(() => _status = 'Clean samples saved to ${externalDir!.path.split('/').last}');
      }
    } catch (e) {
      log('Error preparing demo images: $e');
    }
  }

  Future<void> _pickImage(bool fromCamera) async {
    try {
      final bytes = await _imageService.pickImageBytes(fromCamera: fromCamera);
      if (bytes != null) {
        setState(() {
          _selectedImage = bytes;
          _status = 'Image selected';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _solve() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _response = '';
      _status = 'Benw is thinking...';
    });

    try {
      final result = await _benwService.generateAssistantVisionResponse(
        _selectedImage!,
        _promptController.text,
      );
      setState(() {
        _response = result;
        _status = 'Solved';
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _status = 'Error';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview Area
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(_selectedImage!, fit: BoxFit.contain),
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined, size: 64, color: AppColors.textHint),
                          SizedBox(height: 12),
                          Text('No image selected', style: TextStyle(color: AppColors.textHint)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            
            // Image Selection Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Capture',
                    onTap: () => _pickImage(true),
                    color: AppColors.BenwStart,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload',
                    onTap: () => _pickImage(false),
                    color: AppColors.dopamineStart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Prompt Input
            TextField(
              controller: _promptController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your prompt (e.g. OCR this text, Solve this problem...)',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.psychology_rounded, color: AppColors.BenwStart),
              ),
            ),
            const SizedBox(height: 16),
            
            // Solve Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _solve,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.BenwStart,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: AppColors.BenwStart.withOpacity(0.4),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Ask Benw to Solve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 24),
            
            // Status & Response Area
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'STATUS: $_status',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            
            if (_response.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.BenwStart.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'BENW\'S SOLUTION',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BenwMarkdown(
                      _response,
                      style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
