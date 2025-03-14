import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static Future<File?> pickAndCompressImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image == null) return null;

      // For web, we can't use File directly
      if (kIsWeb) {
        debugPrint('Image picked on web: ${image.path}');
        return File(image.path); // This is just a placeholder for web
      } else {
        return File(image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }
} 