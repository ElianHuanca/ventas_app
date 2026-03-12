import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static const String _defaultApiUrl =
      'https://textilesbackend-production.up.railway.app/api';

  static Future<void> initEnvironment() async {
    await dotenv.load(fileName: '.env');
  }

  static String get apiUrl => dotenv.env['API_URL'] ?? _defaultApiUrl;
}

