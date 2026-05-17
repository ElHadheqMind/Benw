import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> pickImageBytes({required bool fromCamera}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 384,  // Pre-resize for vision encoder requirements
        maxHeight: 384, // Pre-resize for vision encoder requirements
      );

      if (image == null) {
        return null; // User canceled picking
      }

      final bytes = await image.readAsBytes();

      // Clean up temporary camera files to save device storage
      try {
        if (fromCamera) {
          final file = File(image.path);
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      } catch (e) {
        debugPrint('[ImageService] Failed to delete temp file: $e');
      }

      return bytes;
    } catch (e) {
      debugPrint('[ImageService] Error selecting image: $e');
      throw Exception('Failed to pick image: $e');
    }
  }

  // Deprecated OCR method - Benw now handles vision directly
  @deprecated
  Future<String?> pickAndRecognizeText({required bool fromCamera}) async {
    debugPrint('[ImageService] pickAndRecognizeText is deprecated. Use pickImageBytes instead.');
    return null;
  }

  void dispose() {
    // No-op for now
  }
}
