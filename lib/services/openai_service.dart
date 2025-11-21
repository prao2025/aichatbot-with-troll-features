import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  final String? _apiKey;
  final http.Client _client;

  /// Provide [apiKey] at runtime (useful for mobile/web), otherwise fall back to
  /// compile-time define OPENAI_API_KEY. An injectable [client] helps testing.
  OpenAIService({String? apiKey, http.Client? client})
      : _apiKey = apiKey ?? const String.fromEnvironment('OPENAI_API_KEY'),
        _client = client ?? http.Client();

  Future<String> sendMessage(String message, {double temperature = 0.7}) async {
    if (_apiKey == null || _apiKey.isEmpty) {
      throw Exception(
        'OpenAI API key not set. '
        'Set the OPENAI_API_KEY environment variable or update it in the code.',
      );
    }

    try {
      final response = await _client
          .post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': message}
          ],
          'temperature': temperature,
          'max_tokens': 800,
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response body from OpenAI.');
        }
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final choices = decoded['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) {
            throw Exception('No choices returned from OpenAI.');
          }
          final first = choices[0];
          // chat/completions returns { message: { content: ... } } but older endpoints used 'text'
          final content = (first is Map && first['message'] is Map)
              ? first['message']['content']
              : first['text'];
          if (content == null) throw Exception('No reply content in OpenAI response.');
          return content.toString().trim();
        } else {
          throw Exception('Unexpected response format from OpenAI.');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Invalid OpenAI API key (401).');
      } else {
        // try to extract error details from body
        String details = '';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['error'] != null) details = ' - ${err['error']}';
        } catch (_) {}
        throw Exception('Failed to get response: ${response.statusCode}$details');
      }
    } catch (e) {
      // Re-throw with clearer context; keep original message
      throw Exception('Error communicating with OpenAI: $e');
    }
  }
}
