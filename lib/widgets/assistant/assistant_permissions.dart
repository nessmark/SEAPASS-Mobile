/// Rules for what the embedded assistant page may use on the device.
library;

/// File types the assistant accepts (matches the backend attachment list).
const assistantAttachmentExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt'];

const _mimeExtensions = <String, List<String>>{
  'image/jpeg': ['jpg', 'jpeg'],
  'image/png': ['png'],
  'image/webp': ['webp'],
  'image/*': ['jpg', 'jpeg', 'png', 'webp'],
  'application/pdf': ['pdf'],
  'text/plain': ['txt'],
};

/// The WebView may use the microphone only, only for the assistant's own
/// origin, and never the camera or any other resource.
bool shouldGrantAssistantMedia({
  required Iterable<String> requested,
  required Uri? currentUrl,
  required Uri assistantUri,
}) {
  final types = requested.toSet();
  if (types.isEmpty || !types.every((type) => type == 'microphone')) return false;
  return currentUrl != null && _sameOrigin(currentUrl, assistantUri);
}

/// Same-origin navigation only. Everything else stays outside the assistant.
bool isAssistantNavigationAllowed(String url, Uri assistantUri) {
  final destination = Uri.tryParse(url);
  return destination != null && _sameOrigin(destination, assistantUri);
}

bool _sameOrigin(Uri a, Uri b) {
  const web = {'http', 'https'};
  if (!web.contains(a.scheme) || !web.contains(b.scheme) || a.host.isEmpty) return false;
  return a.origin == b.origin;
}

/// Maps a file input's `accept` list to picker extensions, limited to what the
/// assistant accepts. An empty or unknown list falls back to the full set.
List<String> assistantPickerExtensions(Iterable<String> acceptTypes) {
  final wanted = <String>{};
  for (final entry in acceptTypes.expand((value) => value.split(','))) {
    final type = entry.trim().toLowerCase();
    if (type.isEmpty) continue;
    if (type.startsWith('.')) {
      wanted.add(type.substring(1));
    } else {
      wanted.addAll(_mimeExtensions[type] ?? const []);
    }
  }
  final allowed = assistantAttachmentExtensions.where(wanted.contains).toList();
  return allowed.isEmpty ? List.of(assistantAttachmentExtensions) : allowed;
}
