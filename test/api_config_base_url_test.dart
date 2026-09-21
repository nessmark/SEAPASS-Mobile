import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/config/api_config.dart';

void main() {
  group('ApiConfig.normaliseBase', () {
    test('strips a trailing /api so endpoints do not double it', () {
      // The bug: a base of http://host:8000/api plus the endpoint /api/login
      // produced /api/api/login, and Laravel answered
      // "The route api/api/login could not be found."
      expect(ApiConfig.normaliseBase('http://192.168.1.9:8000/api'),
          'http://192.168.1.9:8000');
      expect(ApiConfig.normaliseBase('http://192.168.1.9:8000/api/'),
          'http://192.168.1.9:8000');
      expect(ApiConfig.normaliseBase('http://192.168.1.9:8000/API'),
          'http://192.168.1.9:8000');
    });

    test('strips trailing slashes', () {
      expect(ApiConfig.normaliseBase('http://127.0.0.1:8000/'),
          'http://127.0.0.1:8000');
      expect(ApiConfig.normaliseBase('http://127.0.0.1:8000///'),
          'http://127.0.0.1:8000');
    });

    test('leaves a clean root untouched and trims whitespace', () {
      expect(ApiConfig.normaliseBase('http://127.0.0.1:8000'),
          'http://127.0.0.1:8000');
      expect(ApiConfig.normaliseBase('  https://api.seapass.ph  '),
          'https://api.seapass.ph');
    });

    test('does not eat a host or path that merely contains "api"', () {
      expect(ApiConfig.normaliseBase('https://api.seapass.ph'),
          'https://api.seapass.ph');
      expect(ApiConfig.normaliseBase('http://host:8000/apiary'),
          'http://host:8000/apiary');
    });
  });
}
