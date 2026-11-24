import 'dart:async';
import 'dart:convert';
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

/// Terminal failure. The raw backend detail is deliberately not exposed to the UI.
class AgentFailure extends AgentEvent {}

/// Streams a chat turn from the finance agent backend (`POST /chat/stream`, SSE).
class AgentChatService {
  static const maxHistory = 20;

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

  /// Emits [AgentStatus] events, then exactly one [AgentResult] or [AgentFailure].
  /// Closing [client] (or cancelling the subscription) aborts the request.
  static Stream<AgentEvent> chat({
    required http.Client client,
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? userData,
    String? memory,
  }) async* {
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
    if (res.statusCode != 200) {
      yield AgentFailure();
      return;
    }

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
