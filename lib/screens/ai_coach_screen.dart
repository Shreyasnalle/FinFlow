import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../services/agent_chat_service.dart';
import '../services/ai_coach_service.dart' show ChatMessage;
import '../theme/app_theme.dart';
import '../widgets/markdown_text.dart';
import '../widgets/smooth_wheel.dart';
import '../widgets/tap_scale.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;
  final _replyKey = GlobalKey();

  // In-flight request, cancelled if the screen goes away.
  http.Client? _client;
  StreamSubscription<AgentEvent>? _sub;

  // Latest live status (highest seq wins) and follow-ups for the newest reply only.
  String? _status;
  int _statusSeq = -1;
  List<String> _followups = const [];

  static const _suggestions = [
    'How am I doing this month?',
    'Where can I cut spending?',
    'Am I on track for my goals?',
    'How should I start investing?',
  ];

  static const _errorText =
      'I couldn\'t reach your coach just now. Please check your connection and send your message again.';

  @override
  void dispose() {
    _sub?.cancel();
    _client?.close();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  /// A new reply starts at its first line (follow-ups sit below it and scroll
  /// with the page) instead of jumping to the bottom of a long answer.
  void _scrollToReply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _replyKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      } else {
        _scrollToEnd();
      }
    });
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _thinking) return;
    final provider = context.read<FinanceProvider>();
    final history = AgentChatService.historyFrom(_messages);

    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _controller.clear();
      _thinking = true;
      _status = null;
      _statusSeq = -1;
      _followups = const [];
    });
    _scrollToEnd();

    final client = http.Client();
    _client = client;
    _sub = AgentChatService.chat(
      client: client,
      message: text,
      history: history,
      userData: AgentChatService.userDataFrom(provider),
    ).listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case AgentStatus():
            if (event.seq < _statusSeq || event.message.isEmpty) return;
            setState(() {
              _statusSeq = event.seq;
              _status = event.message;
            });
          case AgentResult():
            _finish(() {
              _messages.add(ChatMessage(fromUser: false, text: event.reply.isEmpty ? '…' : event.reply));
              _followups = event.followups;
            }, toReply: true);
          case AgentFailure():
            _finish(() => _messages.add(ChatMessage(fromUser: false, text: event.message ?? _errorText, isError: true)));
        }
      },
      onError: (_) {
        if (mounted) _finish(() => _messages.add(const ChatMessage(fromUser: false, text: _errorText, isError: true)));
      },
      cancelOnError: true,
    );
  }

  void _finish(VoidCallback change, {bool toReply = false}) {
    _client?.close();
    _client = null;
    _sub = null;
    setState(() {
      change();
      _thinking = false;
      _status = null;
    });
    toReply ? _scrollToReply() : _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final first = provider.userName.trim().split(' ').first;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FinFlow Coach',
                            style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w700, color: context.fg)),
                        Text('Your personal money guide',
                            style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w600, color: context.fgMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _welcome(context, first)
                  : _conversation(context),
            ),
            _composer(context),
          ],
        ),
      ),
    );
  }

  Widget _welcome(BuildContext context, String first) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppTheme.blue, borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi $first,',
                  style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.white.withValues(alpha: 0.85))),
              const SizedBox(height: 4),
              Text('Ask me anything about your money.',
                  style: GoogleFonts.urbanist(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, color: AppTheme.white)),
              const SizedBox(height: 10),
              Text(
                'I can see your balance, budgets, goals and spending, so my answers are about you, not generic tips.',
                style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('Try asking',
            style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w700, color: context.fg)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final s in _suggestions) _chip(context, s)],
        ),
        const SizedBox(height: 22),
        Text(
          'FinFlow Coach gives educational guidance, not licensed financial advice.',
          textAlign: TextAlign.center,
          style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: context.fgFaint),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text) {
    return TapScale(
      onTap: () => _send(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        child: Text(text, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w700, color: context.fg)),
      ),
    );
  }

  /// The whole chat is one scroll view: messages, then the live status or the
  /// follow-ups, so everything scrolls together and nothing is pinned.
  Widget _conversation(BuildContext context) {
    final lastReply = _messages.lastIndexWhere((m) => !m.fromUser && !m.isError);
    final showChips = !_thinking && _followups.isNotEmpty && !_messages.last.fromUser;
    return SingleChildScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SmoothWheel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _messages.length; i++)
              _bubble(context, _messages[i], key: i == lastReply ? _replyKey : null),
            if (_thinking) showLiveStatus(context, _status ?? 'Thinking…'),
            if (showChips) showFollowUps(context, _followups),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m, {Key? key}) {
    final user = m.fromUser;
    final Color bg = user ? context.cta : (m.isError ? AppTheme.blue : context.surface);
    final Color fg = user ? context.onCta : (m.isError ? AppTheme.white : context.fg);
    final plain = user || m.isError;
    return Align(
      key: key,
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: m.text));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (plain ? 0.82 : 0.92)),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(user ? 22 : 6),
              bottomRight: Radius.circular(user ? 6 : 22),
            ),
          ),
          child: plain
              ? Text(m.text, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, color: fg))
              : MarkdownText(m.text, color: fg),
        ),
      ),
    );
  }

  /// Small "working" indicator under the user's message: a spinner plus the
  /// latest status [message], which cross-fades as new status events arrive.
  Widget showLiveStatus(BuildContext context, String message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(22)),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: context.accent)),
              const SizedBox(width: 12),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: context.fgMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Follow-up questions under the newest assistant reply: a plain list (no cards),
  /// each with a down-right arrow, separated by light lines.
  Widget showFollowUps(BuildContext context, List<String> followups) {
    if (followups.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          for (var i = 0; i < followups.length; i++) ...[
            if (i > 0) Divider(color: context.border, height: 1),
            TapScale(
              behavior: HitTestBehavior.opaque,
              onTap: () => _send(followups[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(Icons.subdirectory_arrow_right_rounded, size: 20, color: context.fgFaint),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        followups[i],
                        style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w300, height: 1.35, color: context.fgMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: context.fg),
              decoration: InputDecoration(
                hintText: 'Ask your coach…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    borderSide: BorderSide(color: context.accent, width: 2)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TapScale(
            onTap: _send,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: _thinking ? context.surface : AppTheme.lime, shape: BoxShape.circle),
              child: Icon(Icons.arrow_upward_rounded, color: _thinking ? context.fgFaint : AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}
