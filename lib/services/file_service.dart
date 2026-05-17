import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final ImagePicker _imagePicker = ImagePicker();

  Future<File?> pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      log('Error picking document: $e');
    }
    return null;
  }

  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      log('Error picking image: $e');
    }
    return null;
  }

  Future<String> extractText(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'txt') {
      return await file.readAsString();
    } else if (extension == 'pdf' || extension == 'doc' || extension == 'docx') {
      // For PDF/DOCX, in a real app we'd use a dedicated parser.
      // For this demo, we'll simulate extraction or return the filename as metadata.
      return "Attached Document: ${file.path.split('/').last}";
    }
    return "";
  }
}
