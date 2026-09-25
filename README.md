# aitoolsblocklist for Dart and Flutter

Ask one question about any hostname: is this an AI tool, and if so, what kind? This package answers it from Dart code by calling the lookup endpoint of [search the AI tool register by domain](https://www.aitoolsblocklist.com). It works the same in a Flutter app, a command-line script, or a server written with `shelf` or `dart_frog`.

The register behind the endpoint covers more than 20,000 classified AI tool domains. A lookup returns the category of the tool, the type of AI it offers, and what the vendor's terms say about training on customer data.

## Install

```bash
dart pub add aitoolsblocklist
```

For Flutter projects, `flutter pub add aitoolsblocklist` does the same thing. The only runtime dependency is `package:http`.

## A first lookup

```dart
import 'dart:io';
import 'package:aitoolsblocklist/aitoolsblocklist.dart';

Future<void> main() async {
  final client = AIToolsBlocklistClient(
    apiKey: Platform.environment['AQ_API_KEY'] ?? '',
  );
  try {
    final result = await client.check('chat.openai.com');
    if (result['blocked'] == true) {
      print('${result['domain']} is an AI tool: ${result['primary_category']}');
    } else {
      print('${result['domain']} is not in the register');
    }
  } finally {
    client.close();
  }
}
```

`check` accepts a bare domain or a subdomain. If you pass `eu.app.example-ai.com` and only `example-ai.com` is listed, the response tells you which parent matched.

## What comes back

The client returns an `ApiResult`. Index it like a map, or call `toJson()` for an unmodifiable copy. For a listed domain the fields are:

| Field | Meaning |
|---|---|
| `domain` | The value you sent, normalised |
| `blocked` | `true` when the domain belongs to a known AI tool |
| `matched_domain` | Present only when a parent domain matched instead of the exact name |
| `primary_category` | The main job of the tool, for example writing, image generation or coding |
| `ai_type` | The kind of AI the tool offers |
| `categories` | A list of `{category, subcategory}` pairs for tools that do several things |
| `trains_on_data` | What the vendor terms say about training on your inputs, or `unstated` |
| `opt_out_available` | Whether the terms describe an opt-out |
| `enterprise_no_training` | Whether a business plan excludes training |
| `api_no_training` | Whether API traffic is excluded from training |
| `terms_checked` | The date those terms were last reviewed |

For a domain that is not listed you get `blocked: false` and an empty `categories` list. Treat that as "not a known AI tool", not as "safe".

The word `unstated` matters. It means the terms were read and say nothing on the point. That is a finding in its own right, and many policies treat it the same as "yes".

## Deciding what to do with a result

The register tells you what a tool is. Your policy decides what happens next. A small mapping keeps that decision in one place:

```dart
enum Action { allow, warn, block }

Action decide(ApiResult r) {
  if (r['blocked'] != true) return Action.allow;
  final trains = r['trains_on_data'];
  if (trains == 'yes' || trains == 'unstated') return Action.block;
  return Action.warn;
}
```

Teams usually start with a rule like this and then add exceptions for tools they have approved, keyed on `matched_domain ?? domain`.

## Using it inside a Flutter app

A browser-style app, a kiosk or a managed student device can check a link before opening it. Keep the key off the device if you can. The simplest safe pattern is to route lookups through your own backend and pass that backend's URL as `baseUrl`:

```dart
final client = AIToolsBlocklistClient(
  apiKey: sessionToken,
  baseUrl: 'https://api.your-company.example/ai-lookup',
);
```

Your backend then adds the real key and forwards the call. The client appends `/check` to whatever base you give it.

## Using it on a Dart server

On a proxy or gateway written in Dart, cache results, because the same few hundred domains make up most traffic. A plain map with a timestamp is enough for a single process:

```dart
final _cache = <String, (DateTime, ApiResult)>{};

Future<ApiResult> cachedCheck(AIToolsBlocklistClient c, String host) async {
  final hit = _cache[host];
  if (hit != null && DateTime.now().difference(hit.$1).inHours < 24) {
    return hit.$2;
  }
  final fresh = await c.check(host);
  _cache[host] = (DateTime.now(), fresh);
  return fresh;
}
```

A 24 hour lifetime matches how often the register changes for most domains.

## Timeouts and your own HTTP client

The constructor takes an optional `timeout` (30 seconds by default) and an optional `http.Client`. Passing your own client lets you share connection pools, add logging, or plug in a retry wrapper from another package. Call `close()` when you are done, unless you passed a client you close yourself.

## Errors

| Exception | When it is thrown |
|---|---|
| `ArgumentError` | Empty API key or empty domain, before any network call |
| `AuthenticationException` | HTTP 401 or 403: a missing or wrong key, or the monthly quota is used up |
| `RateLimitException` | HTTP 429: too many requests in a short time |
| `ApiException` | Any other HTTP error, or a response that is not a JSON object |

All three custom types extend `ApiException`, so one `on ApiException catch (e)` covers them. Each carries `statusCode` and the raw `body` for logging. The client does not retry by itself. If you want retries, back off on `RateLimitException` and leave `AuthenticationException` alone, since a retry cannot fix a bad key.

## Testing without the network

`package:http` ships a `MockClient`, which makes unit tests straightforward:

```dart
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final fake = MockClient((req) async => http.Response(
      '{"domain":"example.com","blocked":false,"categories":[]}', 200));
final client = AIToolsBlocklistClient(apiKey: 'test', httpClient: fake);
```

## Getting a key

See [plans, lookup quotas and the downloadable list](https://www.aitoolsblocklist.com/pricing.php) to pick a key. The lookup API is metered per call. The downloadable database suits resolvers and firewalls that need every domain locally.

## Where this fits

A lookup answers questions one domain at a time. Two neighbouring services help when the question is bigger:

- If you want to know which AI tools people already use before writing any rule, [audit which AI tools staff already use](https://www.shadowaitools.com) from existing DNS or proxy logs.
- If software agents browse on your behalf, [stop agents at login and checkout pages](https://www.aiagentallowlist.com) with page-level rules.
- For everything that is not AI, [category feeds for school and office filters](https://www.webfilteringdatabase.com) cover the rest of the web.

## Other clients for the same register

The same lookup is available outside Dart:

- [npm package](https://www.npmjs.com/package/aitoolsblocklist) for Node.js
- [PyPI package](https://pypi.org/project/aitoolsblocklist/) for Python
- [Rust crate](https://crates.io/crates/aitoolsblocklist)

Source for this package lives in the repository linked from the pub.dev sidebar. Issues and pull requests are welcome there.

## License

MIT. See `LICENSE`.
