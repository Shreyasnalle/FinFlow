import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/agent_config.dart';
import '../providers/finance_provider.dart';
import 'ai_coach_service.dart' show ChatMessage;

sealed class AgentEvent {}

class AgentStatus extends AgentEvent {
  AgentStatus(this.seq, this.message);
  final int seq;
  final String message;
}

class AgentResult extends AgentEvent {
  AgentResult({required this.reply, required this.blocked, required this.followups});
  final String reply;
  final bool blocked;
  final List<String> followups;
}

/// Terminal failure. The raw backend detail is deliberately not exposed to the UI;
/// [message] is only ever a friendly sentence written for the user (null = use the generic text).
class AgentFailure extends AgentEvent {
  AgentFailure({this.message});
  final String? message;
}

/// Knows whether the backend is awake. Free hosts (e.g. Render) put a service to sleep after ~15 idle
/// minutes and take about a minute to wake it, which is longer than a normal request timeout. Pinging
/// `/health` first (and waiting for it) turns "coach unavailable" into a short, explained wait.
class AgentWakeUp {
  /// Treat the backend as awake for this long after it last answered (hosts sleep after ~15 minutes).
  static const awakeFor = Duration(minutes: 10);

  /// A cold start takes about a minute; allow some slack.
  static const maxWait = Duration(seconds: 75);

  /// After an unreachable backend, background pre-warms stay quiet for this long.
  static const retryAfterFailure = Duration(seconds: 30);

  static DateTime? _lastOk;
  static DateTime? _lastFail;
  static Future<bool>? _inFlight;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;
  @visibleForTesting
  static http.Client Function() clientFactory = http.Client.new;
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 3);
  @visibleForTesting
  static Duration attemptTimeout = const Duration(seconds: 15);

  static bool get isWarm => _lastOk != null && now().difference(_lastOk!) < awakeFor;

  /// Call when the backend just answered a real request.
  static void markAwake() {
    _lastOk = now();
    _lastFail = null;
  }

  @visibleForTesting
  static void reset() {
    _lastOk = _lastFail = null;
    _inFlight = null;
    now = DateTime.now;
    clientFactory = http.Client.new;
    retryDelay = const Duration(seconds: 3);
    attemptTimeout = const Duration(seconds: 15);
  }

  /// Completes true once `/health` answers 200. Callers share one ping. With [force] false (background
  /// pre-warm) it stays quiet for a while after an unreachable backend instead of retrying on every call.
  static Future<bool> ensureAwake({bool force = false, Duration wait = maxWait}) {
    if (isWarm) return Future.value(true);
    if (!force && _lastFail != null && now().difference(_lastFail!) < retryAfterFailure) {
      return Future.value(false);
    }
    return _inFlight ??= _ping(wait).whenComplete(() => _inFlight = null);
  }

  static Future<bool> _ping(Duration wait) async {
    final client = clientFactory();
    final deadline = now().add(wait);
    try {
      while (true) {
        try {
          final res = await client.get(Uri.parse('$agentBaseUrl/health')).timeout(attemptTimeout);
          if (res.statusCode == 200) {
            markAwake();
            return true;
          }
          // A non-200 (e.g. 502/503) is the host still booting: keep waiting.
        } on TimeoutException {
          // Connection held open while the host boots: try again.
        } catch (_) {
          _lastFail = now();
          return false; // can't even connect (offline, wrong URL, blocked): don't make the user wait
        }
        if (!now().add(retryDelay).isBefore(deadline)) {
          _lastFail = now();
          return false;
        }
        await Future<void>.delayed(retryDelay);
      }
    } finally {
      client.close();
    }
  }
}

/// Streams a chat turn from the finance agent backend (`POST /chat/stream`, SSE).
class AgentChatService {
  static const maxHistory = 20;

  static const wakingMessage = 'Waking up your coach… this can take up to a minute.';
  static const wakeFailedMessage = 'Your coach is taking longer than usual to start. Please try again in a minute.';
  static const slowDownMessage = "You're sending messages too quickly. Please wait a moment and try again.";

  /// Show the "waking up" status only if the wake-up isn't instant.
  @visibleForTesting
  static Duration showWakingAfter = const Duration(seconds: 2);

  /// Earlier turns only (call before adding the new message), last [maxHistory].
  static List<Map<String, String>> historyFrom(List<ChatMessage> messages) {
    final turns = <Map<String, String>>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.isError) continue;
      // A user message that ended in an error never got an answer; skip it.
      if (m.fromUser && i + 1 < messages.length && messages[i + 1].isError) continue;
      turns.add({'role': m.fromUser ? 'user' : 'assistant', 'content': m.text});
    }
    return turns.length > maxHistory ? turns.sublist(turns.length - maxHistory) : turns;
  }

  /// Whatever the app already knows about the user, or null if it isn't ready.
  static Map<String, dynamic>? userDataFrom(FinanceProvider p) {
    try {
      final iso = DateFormat('yyyy-MM-dd');
      return {
        'name': p.userName,
        'profession': p.userProfession,
        'currency': p.currency,
        'today': iso.format(DateTime.now()),
        'cash_balance': p.currentBalance,
        'average_monthly_net': p.averageMonthlyNet,
        'month_income': p.currentMonthIncome,
        'month_spending': p.totalCurrentMonthSpending,
        'month_spending_by_category': p.currentMonthSpendingByCategory,
        'budgets': p.categoryBudgets,
        'goals': [for (final g in p.goals) {'title': g.title, 'saved': g.savedAmount, 'target': g.targetAmount}],
        'recurring_bills': [for (final b in p.bills) {'name': b.name, 'amount': b.amount, 'next_due': iso.format(b.dueDate)}],
        'assets': [for (final a in p.assets) {'name': a.name, 'value': a.value}],
      };
    } catch (_) {
      return null;
    }
  }

  /// The server's friendly `detail` for a 429 (short, written for users), else a generic "slow down".
  static Future<String> _rateLimitMessage(http.StreamedResponse res) async {
    try {
      final body = await res.stream.bytesToString().timeout(const Duration(seconds: 5));
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.trim().isNotEmpty && detail.length <= 200) return detail.trim();
    } catch (_) {}
    return slowDownMessage;
  }

  /// Emits [AgentStatus] events, then exactly one [AgentResult] or [AgentFailure].
  /// Closing [client] (or cancelling the subscription) aborts the request.
  static Stream<AgentEvent> chat({
    required http.Client client,
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? userData,
    String? memory,
  }) async* {
    if (!AgentWakeUp.isWarm) {
      final awake = AgentWakeUp.ensureAwake(force: true);
      final quick = await Future.any<bool?>([awake, Future<bool?>.delayed(showWakingAfter, () => null)]);
      var ok = quick;
      if (ok == null) {
        yield AgentStatus(0, wakingMessage);
        ok = await awake;
      }
      if (!ok) {
        yield AgentFailure(message: wakeFailedMessage);
        return;
      }
    }

    final http.StreamedResponse res;
    try {
      final req = http.Request('POST', Uri.parse('$agentBaseUrl/chat/stream'))
        ..headers['content-type'] = 'application/json'
        ..headers['accept'] = 'text/event-stream'
        ..body = jsonEncode({'message': message, 'history': history, 'user_data': userData, 'memory': memory});
      res = await client.send(req).timeout(const Duration(seconds: 20));
    } catch (_) {
      yield AgentFailure();
      return;
    }
    if (res.statusCode == 429) {
      AgentWakeUp.markAwake(); // it answered, so it is awake
      yield AgentFailure(message: await _rateLimitMessage(res));
      return;
    }
    if (res.statusCode != 200) {
      yield AgentFailure();
      return;
    }
    AgentWakeUp.markAwake();

    var event = 'message';
    final data = <String>[];

    AgentEvent? dispatch() {
      final name = event;
      final raw = data.join('\n');
      event = 'message';
      data.clear();
      if (raw.isEmpty) return null;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        switch (name) {
          case 'status':
            return AgentStatus((json['seq'] as num?)?.toInt() ?? 0, (json['message'] as String? ?? '').trim());
          case 'result':
            return AgentResult(
              reply: (json['reply'] as String? ?? '').trim(),
              blocked: json['blocked'] == true,
              followups: [
                for (final f in (json['followups'] as List? ?? const []))
                  if (f is String && f.trim().isNotEmpty) f.trim()
              ].take(3).toList(),
            );
          case 'error':
            return AgentFailure();
        }
      } catch (_) {}
      return null;
    }

    try {
      final lines = res.stream
          .timeout(const Duration(seconds: 90))
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        AgentEvent? out;
        if (line.isEmpty) {
          out = dispatch();
        } else if (line.startsWith(':')) {
          continue;
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final v = line.substring(5);
          data.add(v.startsWith(' ') ? v.substring(1) : v);
        }
        if (out == null) continue;
        yield out;
        if (out is! AgentStatus) return;
      }
      final last = dispatch();
      if (last != null) {
        yield last;
        if (last is! AgentStatus) return;
      }
    } catch (_) {
      yield AgentFailure();
      return;
    }
    yield AgentFailure();
  }
}
