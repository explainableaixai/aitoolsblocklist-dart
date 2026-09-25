import 'dart:convert';
import 'package:http/http.dart' as http;
import 'exceptions.dart';

class ApiResult {
  ApiResult(this.data);
  final Map<String, dynamic> data;
  dynamic operator [](String key) => data[key];
  Map<String, dynamic> toJson() => Map.unmodifiable(data);
}

class AIToolsBlocklistClient {
  AIToolsBlocklistClient(
      {required this.apiKey,
      String? baseUrl,
      http.Client? httpClient,
      this.timeout = const Duration(seconds: 30)})
      : baseUrl = (baseUrl ?? 'https://www.aitoolsblocklist.com/api')
            .replaceFirst(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client();
  final String apiKey;
  final String baseUrl;
  final Duration timeout;
  final http.Client _http;

  Future<ApiResult> _lookup(String value) async {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('apiKey must not be empty');
    }
    if (value.trim().isEmpty) {
      throw ArgumentError('input must not be empty');
    }
    final endpoint = Uri.parse('$baseUrl/check');
    late http.Response response;
    final uri = endpoint.replace(queryParameters: {'domain': value});
    response = await _http.get(uri, headers: {
      'X-API-Key': apiKey,
      'Accept': 'application/json'
    }).timeout(timeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthenticationException('Authentication or quota failure',
          statusCode: response.statusCode, body: response.body);
    }
    if (response.statusCode == 429) {
      throw RateLimitException('Rate limited',
          statusCode: 429, body: response.body);
    }
    if (response.statusCode >= 400) {
      throw ApiException('API request failed',
          statusCode: response.statusCode, body: response.body);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Expected a JSON object',
          statusCode: response.statusCode, body: response.body);
    }
    return ApiResult(decoded);
  }

  Future<ApiResult> check(String value) => _lookup(value);
  void close() => _http.close();
}
