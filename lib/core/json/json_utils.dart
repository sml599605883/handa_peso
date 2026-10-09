/// Lightweight, defensive helpers for reading loosely-typed API payloads.
///
/// Backend responses are frequently inconsistent (missing keys, `null` in place
/// of numbers, strings where numbers are expected). These extensions keep the
/// parsing code readable without pulling a heavy code-generation layer.
extension JsonMap on Map<String, dynamic> {
  Map<String, dynamic>? mapOrNull(String key) {
    final value = this[key];
    return value is Map<String, dynamic> ? value : null;
  }

  Map<String, dynamic> mapOf(String key) => mapOrNull(key) ?? const <String, dynamic>{};

  List<dynamic> listValue(String key) {
    final value = this[key];
    return value is List ? value : const <dynamic>[];
  }

  String stringValue(String key, {String fallback = ''}) {
    final value = this[key];
    if (value == null) return fallback;
    return value.toString();
  }

  int intValue(String key, {int fallback = 0}) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool boolValue(String key, {bool fallback = false}) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}

extension JsonList on List<dynamic> {
  List<Map<String, dynamic>> get maps =>
      whereType<Map<String, dynamic>>().toList(growable: false);
}
