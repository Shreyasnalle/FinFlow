import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/agent_chat_service.dart';
import '../theme/app_theme.dart';

/// Asks the AI coach for suggestions on already-computed forecast numbers.
/// Used on both the Forecast and Goals pages.
class AiForecastInsightCard extends StatefulWidget {
  /// Builds the numbers sent to the coach. Called when the user taps the button.
  final String Function() buildFacts;
  final String title;

  const AiForecastInsightCard({
    super.key,
    required this.buildFacts,
    this.title = 'AI coach suggestion',
  });

  @override
  State<AiForecastInsightCard> createState() => _AiForecastInsightCardState();
}

class _AiForecastInsightCardState extends State<AiForecastInsightCard> {
  String? _reply;
  String? _error;
  bool _loading = false;

  http.Client? _client;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _run(FinanceProvider provider) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = http.Client();
    _client = client;
    var prompt = 'Here are forecast numbers already calculated by the app:\n'
        '${widget.buildFacts()}\n\n'
        'In at most 4 short bullet points, tell me the most useful, concrete '
        'actions to improve this outlook (for example which spending to trim '
        'and how much sooner a goal would be reached). Use only these numbers '
        'and my snapshot; do not recalculate or invent figures.';
    if (prompt.length > 1900) prompt = prompt.substring(0, 1900);

    String? reply;
    await for (final e in AgentChatService.chat(
      client: client,
      message: prompt,
      history: const [],
      userData: AgentChatService.userDataFrom(provider),
    )) {
      if (e is AgentResult) reply = e.reply;
    }
    _client = null;
    client.close();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (reply != null && reply.isNotEmpty) {
        _reply = reply;
      } else {
        _error = 'I couldn\'t reach your coach just now. Please check your connection and try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 20, color: context.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_reply != null)
              Text(_reply!,
                  style: GoogleFonts.urbanist(
                      fontSize: 14, height: 1.45, color: context.fg))
            else if (_error != null)
              Text(_error!,
                  style: GoogleFonts.urbanist(
                      fontSize: 13, color: Theme.of(context).colorScheme.error))
            else
              Text(
                'Get personal tips based on these numbers.',
                style: GoogleFonts.urbanist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.fgMuted),
              ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _loading ? null : () => _run(provider),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lightbulb_outline_rounded, size: 18),
                label: Text(_reply == null ? 'Get suggestion' : 'Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
