import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:async';

class PathProviderPlugin {
  static void registerWith(Registrar registrar) {
    // No implementation needed for web
  }

  static Future<String> getTemporaryPath() async {
    return '/tmp';
  }
} 