import 'dart:io';
import 'package:aitoolsblocklist/aitoolsblocklist.dart';

Future<void> main() async {
  final client =
      AIToolsBlocklistClient(apiKey: Platform.environment['AQ_API_KEY'] ?? '');
  try {
    print(await client.check('chat.openai.com'));
  } finally {
    client.close();
  }
}
