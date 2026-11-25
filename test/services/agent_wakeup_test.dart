import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_finance_app/services/agent_chat_service.dart';

http.StreamedResponse sse(String body, {int status = 200}) => http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': status == 200 ? 'text/event-stream' : 'application/json'},
    );

const okResult = 'event: result\ndata: {"reply":"Hello","blocked":false,"followups":["a?","b?","c?"]}\n\n';

Future<List<AgentEvent>> collect(http.Client client) => AgentChatService.chat(
      client: client,
      message: 'hi',
      history: const [],
    ).toList();

void main() {
  setUp(() {
    AgentWakeUp.reset();
    AgentWakeUp.retryDelay = Duration.zero;
    AgentChatService.showWakingAfter = const Duration(milliseconds: 20);
  });
  tearDown(AgentWakeUp.reset);

  group('AgentWakeUp', () {
    test('does not ping while the backend is known to be awake', () async {
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            return http.Response('{"status":"ok"}', 200);
          });
      AgentWakeUp.markAwake();
      expect(await AgentWakeUp.ensureAwake(), isTrue);
      expect(pings, 0);
    });

    test('forgets that it was awake after 10 minutes', () {
      var t = DateTime(2026, 1, 1, 12);
      AgentWakeUp.now = () => t;
      AgentWakeUp.markAwake();
      t = t.add(const Duration(minutes: 9));
      expect(AgentWakeUp.isWarm, isTrue);
      t = t.add(const Duration(minutes: 2));
      expect(AgentWakeUp.isWarm, isFalse);
    });

    test('keeps retrying while the host answers 503 (still booting), then succeeds', () async {
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            expect(r.url.path, '/health');
            pings++;
            return pings < 4 ? http.Response('starting', 503) : http.Response('{"status":"ok"}', 200);
          });
      expect(await AgentWakeUp.ensureAwake(), isTrue);
      expect(pings, 4);
      expect(AgentWakeUp.isWarm, isTrue);
    });

    test('retries when the connection is held open (timeout) while booting', () async {
      var pings = 0;
      AgentWakeUp.attemptTimeout = const Duration(milliseconds: 20);
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            if (pings < 3) await Completer<void>().future; // never answers: the attempt times out
            return http.Response('{"status":"ok"}', 200);
          });
      expect(await AgentWakeUp.ensureAwake(), isTrue);
      expect(pings, 3);
    });

    test('fails fast when the backend cannot be reached at all', () async {
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            throw http.ClientException('connection refused');
          });
      expect(await AgentWakeUp.ensureAwake(), isFalse);
      expect(pings, 1);
      expect(AgentWakeUp.isWarm, isFalse);
    });

    test('gives up after the maximum wait', () async {
      var t = DateTime(2026, 1, 1, 12);
      AgentWakeUp.now = () => t;
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            t = t.add(const Duration(seconds: 4)); // each attempt "takes" 4 s of the 75 s budget
            return http.Response('starting', 503);
          });
      final result = await AgentWakeUp.ensureAwake(wait: const Duration(seconds: 20));
      expect(result, isFalse);
      expect(pings, inInclusiveRange(4, 6));
    });

    test('concurrent callers share a single ping', () async {
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return http.Response('{"status":"ok"}', 200);
          });
      final results = await Future.wait([AgentWakeUp.ensureAwake(), AgentWakeUp.ensureAwake(), AgentWakeUp.ensureAwake()]);
      expect(results, [true, true, true]);
      expect(pings, 1);
    });

    test('background pre-warm stays quiet after a failure, but a real chat (force) still tries', () async {
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            throw http.ClientException('offline');
          });
      expect(await AgentWakeUp.ensureAwake(), isFalse);
      expect(await AgentWakeUp.ensureAwake(), isFalse); // suppressed, no new request
      expect(pings, 1);
      expect(await AgentWakeUp.ensureAwake(force: true), isFalse);
      expect(pings, 2);
    });
  });

  group('AgentChatService.chat with a sleeping backend', () {
    test('cold start: shows "waking up", waits, then streams the reply', () async {
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            await Future<void>.delayed(const Duration(milliseconds: 80)); // slower than showWakingAfter
            return http.Response('{"status":"ok"}', 200);
          });
      final client = MockClient.streaming((req, body) async => sse(okResult));
      final events = await collect(client);
      expect(events.first, isA<AgentStatus>());
      expect((events.first as AgentStatus).message, AgentChatService.wakingMessage);
      expect(events.last, isA<AgentResult>());
      expect((events.last as AgentResult).reply, 'Hello');
    });

    test('a quick wake-up shows no "waking up" status', () async {
      AgentWakeUp.clientFactory = () => MockClient((r) async => http.Response('{"status":"ok"}', 200));
      final client = MockClient.streaming((req, body) async => sse(okResult));
      final events = await collect(client);
      expect(events.whereType<AgentStatus>(), isEmpty);
      expect(events.single, isA<AgentResult>());
    });

    test('an awake backend is not pinged before the chat request', () async {
      var pings = 0;
      AgentWakeUp.clientFactory = () => MockClient((r) async {
            pings++;
            return http.Response('{"status":"ok"}', 200);
          });
      AgentWakeUp.markAwake();
      final events = await collect(MockClient.streaming((req, body) async => sse(okResult)));
      expect(pings, 0);
      expect(events.single, isA<AgentResult>());
    });

    test('a backend that never wakes gives a clear message and sends no chat request', () async {
      AgentWakeUp.clientFactory = () => MockClient((r) async => throw http.ClientException('down'));
      var chatRequests = 0;
      final client = MockClient.streaming((req, body) async {
        chatRequests++;
        return sse(okResult);
      });
      final events = await collect(client);
      final failure = events.last as AgentFailure;
      expect(failure.message, AgentChatService.wakeFailedMessage);
      expect(chatRequests, 0);
    });

    test('a 429 shows the server\'s friendly sentence and marks the backend awake', () async {
      AgentWakeUp.markAwake();
      final client = MockClient.streaming((req, body) async =>
          sse('{"detail":"You\'re sending messages too quickly. Please wait a moment and try again."}', status: 429));
      final events = await collect(client);
      expect((events.single as AgentFailure).message, contains('too quickly'));
      expect(AgentWakeUp.isWarm, isTrue);
    });

    test('a 429 with an unreadable body falls back to the generic slow-down sentence', () async {
      AgentWakeUp.markAwake();
      final client = MockClient.streaming((req, body) async => sse('<html>nope</html>', status: 429));
      final events = await collect(client);
      expect((events.single as AgentFailure).message, AgentChatService.slowDownMessage);
    });

    test('other errors keep the generic failure (no message)', () async {
      AgentWakeUp.markAwake();
      final client = MockClient.streaming((req, body) async => sse('{"detail":"boom"}', status: 500));
      final events = await collect(client);
      expect((events.single as AgentFailure).message, isNull);
    });

    test('a successful chat marks the backend awake for later messages', () async {
      AgentWakeUp.clientFactory = () => MockClient((r) async => http.Response('{"status":"ok"}', 200));
      await collect(MockClient.streaming((req, body) async => sse(okResult)));
      expect(AgentWakeUp.isWarm, isTrue);
    });
  });
}
