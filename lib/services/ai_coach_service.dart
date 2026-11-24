import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';

class ChatMessage {
  final bool fromUser;
  final String text;
  final bool isError;
  const ChatMessage({required this.fromUser, required this.text, this.isError = false});
}

/// Talks to Claude using the user's own API key (stored on-device only).
class AiCoachService {
  static const _model = 'claude-sonnet-5-5';

  /// Snapshot of the user's finances so answers are personal.
  static String _context(FinanceProvider p) {
    final fmt = NumberFormat.compact();
    final month = DateFormat('MMMM yyyy').format(DateTime.now());
    final spending = p.currentMonthSpendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final assetsTotal = p.assets.fold<double>(0, (s, a) => s + a.value);
    final b = StringBuffer()
      ..writeln('User: ${p.userName}${p.userProfession.isNotEmpty ? ' (${p.userProfession})' : ''}')
      ..writeln('Currency: ${p.currency}')
      ..writeln('Today: ${DateFormat('d MMM yyyy').format(DateTime.now())}')
      ..writeln('Cash balance: ${p.currentBalance.toStringAsFixed(0)}')
      ..writeln('Assets total: ${assetsTotal.toStringAsFixed(0)}')
      ..writeln('Average monthly net: ${p.averageMonthlyNet.toStringAsFixed(0)}')
      ..writeln('$month income: ${p.currentMonthIncome.toStringAsFixed(0)}')
      ..writeln('$month spending: ${p.totalCurrentMonthSpending.toStringAsFixed(0)}');
    if (spending.isNotEmpty) {
      b.writeln('Spending by category this month: ${spending.take(8).map((e) => '${e.key} ${fmt.format(e.value)}').join(', ')}');
    }
    if (p.categoryBudgets.isNotEmpty) {
      b.writeln('Budgets: ${p.categoryBudgets.entries.map((e) => '${e.key} ${fmt.format(e.value)}').join(', ')}');
    }
    if (p.goals.isNotEmpty) {
      b.writeln('Goals: ${p.goals.map((g) => '${g.title} ${fmt.format(g.savedAmount)}/${fmt.format(g.targetAmount)}').join('; ')}');
    }
    if (p.bills.isNotEmpty) {
      b.writeln('Recurring bills: ${p.bills.map((x) => '${x.name} ${fmt.format(x.amount)}').join(', ')}');
    }
    if (p.assets.isNotEmpty) {
      b.writeln('Assets: ${p.assets.map((a) => '${a.name} ${fmt.format(a.value)}').join(', ')}');
    }
    return b.toString();
  }

  static String _system(FinanceProvider p) => '''
You are FinFlow Coach, a friendly, practical personal-finance coach inside the FinFlow app.
Use the user's real numbers below to personalise every answer. Be concise (short paragraphs or a few bullets), concrete, and encouraging.
You are not a licensed financial advisor: give educational guidance, explain trade-offs, and never promise returns or tell the user to buy or sell a specific security.
If data is missing or zero, say so and suggest what to log to get better advice.

--- USER'S FINANCIAL SNAPSHOT ---
${_context(p)}''';

  /// One-shot, short suggestion based on forecast numbers computed in code.
  /// The model only explains and advises; it never does the maths.
  static Future<String> suggest({
    required String apiKey,
    required FinanceProvider provider,
    required String facts,
  }) {
    final prompt = 'Here are forecast numbers already calculated by the app:\n'
        '$facts\n\n'
        'In at most 4 short bullet points, tell me the most useful, concrete '
        'actions to improve this outlook (for example which spending to trim '
        'and how much sooner a goal would be reached). Use only these numbers '
        'and my snapshot; do not recalculate or invent figures.';
    return ask(
      apiKey: apiKey,
      provider: provider,
      history: [ChatMessage(fromUser: true, text: prompt)],
    );
  }

  /// Returns the assistant's reply, or throws [AiCoachException].
  static Future<String> ask({
    required String apiKey,
    required FinanceProvider provider,
    required List<ChatMessage> history,
  }) async {
    final messages = history
        .where((m) => !m.isError)
        .map((m) => {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 900,
              'system': _system(provider),
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw AiCoachException('Could not reach the AI service. Check your connection and try again.');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw AiCoachException('That API key was rejected. Update it from the key icon and try again.');
    }
    if (res.statusCode == 429) {
      throw AiCoachException('Too many requests right now. Wait a moment and try again.');
    }
    if (res.statusCode != 200) {
      throw AiCoachException('The AI service returned an error (${res.statusCode}).');
    }
    final content = (jsonDecode(res.body)['content'] as List).whereType<Map>();
    return content.where((c) => c['type'] == 'text').map((c) => c['text']).join('\n').trim();
  }
}

class AiCoachException implements Exception {
  final String message;
  AiCoachException(this.message);
}
