import '../json/json_utils.dart';

/// Normalised envelope returned by the API client.
class ApiResponse {
  const ApiResponse({required this.code, required this.message, required this.raw});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      code: json.intValue('code', fallback: -1),
      message: json.stringValue('message', fallback: json.stringValue('msg')),
      raw: json,
    );
  }

  final int code;
  final String message;
  final Map<String, dynamic> raw;

  bool get isSuccess => code == 0 || code == 200;

  Map<String, dynamic> get data => raw.mapOrNull('data') ?? raw;
}
