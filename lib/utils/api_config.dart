import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _productionUrl = 'https://flutter21-production.up.railway.app';

  static const String _deviceServerIP = '192.168.1.100';
  static const int _port = 3001;

  static String get baseUrl {
    // Production build always uses Railway
    if (kReleaseMode) return _productionUrl;

    // Debug: platform-specific localhost
    if (kIsWeb) return 'http://localhost:$_port';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:$_port';
    return 'http://localhost:$_port';
  }

  static String get deviceBaseUrl => 'http://$_deviceServerIP:$_port';
}
