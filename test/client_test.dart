import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:aitoolsblocklist/aitoolsblocklist.dart';

void main() {
  test('decodes a successful response', () async {
    final mock = MockClient((request) async {
      expect(request.url.path, contains('check'));
      return http.Response('{"ok":true}', 200);
    });
    final client = AIToolsBlocklistClient(
        apiKey: 'test', baseUrl: 'https://example.test/api', httpClient: mock);
    final result = await client.check('chat.openai.com');
    expect(result['ok'], isTrue);
  });
}
