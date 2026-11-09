import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/widgets/assistant/assistant_permissions.dart';

void main() {
  final assistant = Uri.parse('https://seapass.example.ph/assistant/embed');

  group('WebView media requests', () {
    test('grants the microphone only to the assistant origin', () {
      expect(
          shouldGrantAssistantMedia(
              requested: ['microphone'],
              currentUrl: Uri.parse('https://seapass.example.ph/assistant/embed?x=1'),
              assistantUri: assistant),
          isTrue);
    });

    test('refuses the camera, mixed requests and empty requests', () {
      final here = Uri.parse('https://seapass.example.ph/assistant/embed');
      expect(shouldGrantAssistantMedia(requested: ['camera'], currentUrl: here, assistantUri: assistant), isFalse);
      expect(shouldGrantAssistantMedia(requested: ['microphone', 'camera'], currentUrl: here, assistantUri: assistant),
          isFalse);
      expect(shouldGrantAssistantMedia(requested: const [], currentUrl: here, assistantUri: assistant), isFalse);
    });

    test('refuses other origins, other schemes, other ports and unknown pages', () {
      for (final url in [
        'https://evil.example.com/assistant/embed',
        'http://seapass.example.ph/assistant/embed',
        'https://seapass.example.ph:8443/assistant/embed',
        'file:///sdcard/page.html',
        'about:blank',
      ]) {
        expect(
            shouldGrantAssistantMedia(requested: ['microphone'], currentUrl: Uri.parse(url), assistantUri: assistant),
            isFalse,
            reason: url);
      }
      expect(shouldGrantAssistantMedia(requested: ['microphone'], currentUrl: null, assistantUri: assistant), isFalse);
    });
  });

  test('navigation stays on the assistant origin', () {
    expect(isAssistantNavigationAllowed('https://seapass.example.ph/assistant/embed#chat', assistant), isTrue);
    expect(isAssistantNavigationAllowed('https://seapass.example.ph/api/assistant/report', assistant), isTrue);
    expect(isAssistantNavigationAllowed('https://pm.link/pay/123', assistant), isFalse);
    expect(isAssistantNavigationAllowed('intent://scan#Intent;end', assistant), isFalse);
    expect(isAssistantNavigationAllowed('javascript:alert(1)', assistant), isFalse);
  });

  group('file picker types', () {
    test('maps accept lists to the types the assistant takes', () {
      expect(assistantPickerExtensions(['image/*']), ['jpg', 'jpeg', 'png', 'webp']);
      expect(assistantPickerExtensions(['application/pdf,.txt']), ['pdf', 'txt']);
      expect(assistantPickerExtensions(['.PNG', 'image/png']), ['png']);
    });

    test('never widens to other types, and falls back to the full set', () {
      expect(assistantPickerExtensions(['.exe', 'application/zip']), assistantAttachmentExtensions);
      expect(assistantPickerExtensions(const []), assistantAttachmentExtensions);
      expect(assistantPickerExtensions(['']), assistantAttachmentExtensions);
    });
  });
}
