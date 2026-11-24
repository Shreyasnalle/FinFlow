import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/finance_provider.dart';
import '../services/market_movers_service.dart';
import '../services/market_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_scale.dart';
import '../widgets/smooth_wheel.dart';

String _timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// ₹ prices use Indian grouping (55,45,835.00) to match the rest of the app.
String _price(double v, String prefix) =>
    NumberFormat('#,##0.00', prefix == '₹' ? 'en_IN' : 'en_US').format(v);

const _currencySymbols = {'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'AUD': 'A\$', 'CAD': 'C\$'};

/// Currency prefix for a quote shown under [category].
String _prefixFor(MarketQuote q, MarketCategory category) {
  if (q.currency != null) return _currencySymbols[q.currency!.toUpperCase()] ?? '';
  return switch (category) {
    MarketCategory.india => '₹',
    MarketCategory.us || MarketCategory.commodities => '\$',
    _ => '',
  };
}

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  MarketCategory _category = MarketCategory.india;
  final _movers = <MarketCategory, List<MarketQuote>>{};
  List<NewsItem>? _news;
  bool _loading = false;
  DateTime? _updated;

  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;
  bool _searching = false;
  List<MarketQuote>? _results;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _vs() {
    final parts = context.read<FinanceProvider>().currency.split(' ');
    final code = parts.length > 1 ? parts.last.toLowerCase() : 'usd';
    return const {'inr', 'usd', 'eur', 'gbp', 'jpy', 'aud', 'cad'}.contains(code) ? code : 'usd';
  }

  Future<void> _loadCategory(MarketCategory c, String vs) async {
    var r = await MarketMoversService.fetchTopMovers(c, vsCurrency: vs);
    // Yahoo is blocked in browsers; ECB rates still give the Forex tab something real.
    if (r.isEmpty && c == MarketCategory.forex) r = await MarketService.fetchForex();
    if (mounted) setState(() => _movers[c] = r);
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final vs = _vs();
    setState(() => _loading = true);
    await Future.wait([
      for (final c in MarketCategory.values) _loadCategory(c, vs),
      MarketService.fetchNews().then((r) {
        if (mounted) setState(() => _news = r);
      }),
    ]);
    if (!mounted) return;
    setState(() {
      _updated = DateTime.now();
      _loading = false;
    });
  }

  void _selectCategory(MarketCategory c) {
    _debounce?.cancel();
    _searchSeq++;
    _searchCtrl.clear();
    setState(() {
      _category = c;
      _results = null;
      _searching = false;
    });
  }

  void _toggleSearch() {
    _debounce?.cancel();
    _searchSeq++;
    _searchCtrl.clear();
    setState(() {
      _searchOpen = !_searchOpen;
      _results = null;
      _searching = false;
    });
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    final seq = ++_searchSeq;
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final category = _category;
      final r = await MarketMoversService.search(category, q, vsCurrency: _vs());
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    });
  }

  void _openDetail(MarketQuote q) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuoteDetailSheet(quote: q, category: _category, vs: _vs()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.ink,
          backgroundColor: AppTheme.lime,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [SmoothWheel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invest &\nmarkets',
                      style: GoogleFonts.urbanist(fontSize: 34, fontWeight: FontWeight.w700, height: 1.1, color: context.fg),
                    ),
                  ),
                  TapScale(
                    onTap: _refresh,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.ink),
                            )
                          : const Icon(Icons.refresh_rounded, color: AppTheme.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _marketsCard(context),
              const SizedBox(height: 16),
              _newsCard(context),
              const SizedBox(height: 16),
              _learnCard(context),
              if (_updated != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Updated ${DateFormat('h:mm a').format(_updated!)} · pull down to refresh',
                    style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: context.fgFaint),
                  ),
                ),
              ],
            ]))],
          ),
        ),
      ),
    );
  }

  // ── Shared card chrome ──

  Widget _card(BuildContext context, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _cardTitle(BuildContext context, String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w700, color: context.fg)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _message(BuildContext context, String text, {bool loading = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: context.accent)),
                  const SizedBox(width: 10),
                  Text(text, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: context.fgMuted)),
                ],
              )
            : Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: context.fgMuted),
              ),
      ),
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> rows) {
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Divider(color: context.border, height: 1),
        rows[i],
      ],
    ];
  }

  // ── Markets ──

  Widget _pill(BuildContext context, MarketCategory c) {
    final selected = _category == c;
    return TapScale(
      onTap: () => _selectCategory(c),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.lime : context.bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          c.label,
          style: GoogleFonts.urbanist(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.ink : context.fgMuted,
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: context.fg),
        decoration: InputDecoration(
          hintText: 'Search ${_category.label.toLowerCase()}',
          prefixIcon: Icon(Icons.search_rounded, color: context.fgMuted),
          filled: true,
          fillColor: context.bg,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            borderSide: BorderSide(color: context.accent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _quoteRow(BuildContext context, MarketQuote q) {
    final letters = q.symbol.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final chip = letters.isEmpty ? '' : letters.substring(0, math.min(3, letters.length)).toUpperCase();
    return TapScale(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(q),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.soft, shape: BoxShape.circle),
              child: Text(chip, style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.w800, color: context.onSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w700, color: context.fg)),
                  Text(q.symbol.replaceAll('.NS', '').replaceAll('.BO', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: context.fgMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_prefixFor(q, _category)}${_price(q.price, _prefixFor(q, _category))}',
                    style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w700, color: context.fg)),
                const SizedBox(height: 4),
                _changeChip(q.changePct),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _marketsCard(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final showResults = _searchOpen && query.isNotEmpty;
    final movers = _movers[_category];

    final List<Widget> body;
    if (showResults) {
      if (_searching) {
        body = [_message(context, 'Searching…', loading: true)];
      } else if (_results == null || _results!.isEmpty) {
        body = [_message(context, 'Nothing found for "$query" in ${_category.label}.\nIf you expected a match, wait a moment and try again.')];
      } else {
        body = _withDividers(context, [for (final q in _results!) _quoteRow(context, q)]);
      }
    } else if (movers == null) {
      body = [_message(context, 'Fetching ${_category.label.toLowerCase()}…', loading: true)];
    } else if (movers.isEmpty) {
      final blockedOnWeb = kIsWeb && const [MarketCategory.india, MarketCategory.us, MarketCategory.commodities].contains(_category);
      body = [
        _message(
          context,
          blockedOnWeb
              ? 'Live stock and commodity quotes are blocked in web browsers. They load in the phone app; Forex and Crypto work here.'
              : 'Couldn\'t load ${_category.label.toLowerCase()} right now. Pull down to retry.',
        ),
      ];
    } else {
      body = [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text('Top movers today',
              style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.fgMuted)),
        ),
        ..._withDividers(context, [for (final q in movers) _quoteRow(context, q)]),
      ];
    }

    return _card(context, [
      _cardTitle(
        context,
        'Markets',
        trailing: TapScale(
          onTap: _toggleSearch,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _searchOpen ? AppTheme.lime : context.bg, shape: BoxShape.circle),
            child: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded,
                size: 20, color: _searchOpen ? AppTheme.ink : context.fg),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final c in MarketCategory.values) _pill(context, c)]),
      ),
      if (_searchOpen) _searchField(context),
      const SizedBox(height: 6),
      ...body,
    ]);
  }

  // ── News ──

  Widget _newsCard(BuildContext context) {
    final items = _news;
    final List<Widget> body;
    if (items == null) {
      body = [_message(context, 'Fetching top news…', loading: true)];
    } else if (items.isEmpty) {
      body = [_message(context, 'Couldn\'t load news right now. Pull down to retry.')];
    } else {
      body = _withDividers(context, [for (final n in items) _NewsRow(item: n)]);
    }
    return _card(context, [
      _cardTitle(
        context,
        'Top news',
        trailing: (items == null || items.isEmpty)
            ? null
            : Text('Top ${items.length} today',
                style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: context.fgMuted)),
      ),
      const SizedBox(height: 6),
      ...body,
    ]);
  }

  // ── Learn ──

  static const _lessons = <(String, String, String)>[
    ('SIP', 'Invest a fixed amount every month',
        'A Systematic Investment Plan puts a fixed sum into a fund at regular intervals. You buy more units when prices are low and fewer when high, which averages your cost and builds the habit of investing without timing the market.'),
    ('Compounding', 'Returns that earn their own returns',
        'Gains you reinvest start earning gains themselves. Time matters more than amount: starting 10 years earlier can beat investing twice as much later. Rule of 72: divide 72 by the yearly return to estimate how many years it takes to double.'),
    ('Emergency fund', 'Your safety net first',
        'Keep 3 to 6 months of essential expenses in an easy-access account before taking investment risk. It stops a job loss or medical bill from forcing you to sell investments at a bad time.'),
    ('50/30/20 rule', 'A simple way to split income',
        'Roughly 50% of income to needs, 30% to wants and 20% to savings and investing. Use it as a starting point and adjust to your situation.'),
    ('Diversification', 'Don\'t put it all in one basket',
        'Spreading money across stocks, bonds, gold and cash reduces the damage when any single asset falls. Index funds are a low-cost way to get broad exposure.'),
    ('Inflation', 'Why idle cash loses value',
        'Prices rise over time, so money that earns less than inflation buys less each year. Compare returns after inflation (real returns), not just the headline number.'),
  ];

  Widget _lessonRow(BuildContext context, (String, String, String) l) {
    return TapScale(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showLesson(context, l),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.$1, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w700, color: context.fg)),
                  const SizedBox(height: 2),
                  Text(l.$2, style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w500, color: context.fgMuted)),
                ],
              ),
            ),
            const _ArrowChip(),
          ],
        ),
      ),
    );
  }

  Widget _learnCard(BuildContext context) {
    return _card(context, [
      _cardTitle(context, 'Learn'),
      const SizedBox(height: 6),
      ..._withDividers(context, [for (final l in _lessons) _lessonRow(context, l)]),
    ]);
  }

  void _showLesson(BuildContext context, (String, String, String) l) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.$1, style: GoogleFonts.urbanist(fontSize: 28, fontWeight: FontWeight.w700, color: context.fg)),
            const SizedBox(height: 4),
            Text(l.$2, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: context.accent)),
            const SizedBox(height: 16),
            Text(l.$3,
                style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: context.fgMuted)),
          ],
        ),
      ),
    );
  }
}

Widget _changeChip(double pct) {
  final up = pct >= 0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: up ? AppTheme.lime : AppTheme.blue,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
    ),
    child: Text(
      '${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
      style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w800, color: up ? AppTheme.ink : AppTheme.white),
    ),
  );
}

class _ArrowChip extends StatelessWidget {
  const _ArrowChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
      child: const Icon(Icons.north_east_rounded, size: 15, color: AppTheme.ink),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final meta = [if (item.source.isNotEmpty) item.source, _timeAgo(item.published)].where((s) => s.isNotEmpty).join(' · ');
    return TapScale(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.thumbnail != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  item.thumbnail!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, color: context.fg),
                  ),
                  const SizedBox(height: 6),
                  Text(meta, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: context.fgMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _ArrowChip(),
          ],
        ),
      ),
    );
  }
}

/// Price chart (with range picker) and related news for one quote.
class _QuoteDetailSheet extends StatefulWidget {
  const _QuoteDetailSheet({required this.quote, required this.category, required this.vs});
  final MarketQuote quote;
  final MarketCategory category;
  final String vs;

  @override
  State<_QuoteDetailSheet> createState() => _QuoteDetailSheetState();
}

class _QuoteDetailSheetState extends State<_QuoteDetailSheet> {
  ChartRange _range = ChartRange.month;
  List<ChartPoint>? _points;
  List<NewsItem>? _news;

  @override
  void initState() {
    super.initState();
    _loadChart();
    _loadNews();
  }

  /// Forex fallback rows use `USD/INR`; Yahoo wants `INR=X`.
  String get _chartSymbol {
    final s = widget.quote.symbol;
    return s.startsWith('USD/') ? '${s.substring(4)}=X' : s;
  }

  Future<void> _loadChart() async {
    final range = _range;
    setState(() => _points = null);
    final q = widget.quote;
    final pts = (widget.category == MarketCategory.crypto && q.id != null)
        ? await MarketService.fetchCryptoChart(q.id!, widget.vs, range)
        : await MarketService.fetchChart(_chartSymbol, range);
    if (!mounted || range != _range) return;
    setState(() => _points = pts);
  }

  Future<void> _loadNews() async {
    final q = widget.quote;
    final topic = widget.category == MarketCategory.crypto ? q.name : q.symbol;
    final r = await MarketService.fetchSymbolNews(topic, count: 6);
    if (mounted) setState(() => _news = r);
  }

  String _axisTime(DateTime t) => switch (_range) {
        ChartRange.day => DateFormat('h:mm a').format(t),
        ChartRange.week || ChartRange.month || ChartRange.threeMonths => DateFormat('d MMM, h:mm a').format(t),
        _ => DateFormat('d MMM yyyy').format(t),
      };

  Widget _chart(BuildContext context, String prefix) {
    final pts = _points;
    if (pts == null) {
      return SizedBox(height: 210, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: context.accent)));
    }
    if (pts.length < 2) {
      return SizedBox(
        height: 210,
        child: Center(
          child: Text('Couldn\'t load the chart for this range.\nTry another range or check your connection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: context.fgMuted)),
        ),
      );
    }
    final prices = pts.map((p) => p.price);
    final lo = prices.reduce(math.min);
    final hi = prices.reduce(math.max);
    final pad = hi == lo ? hi.abs() * 0.01 + 0.01 : (hi - lo) * 0.12;
    final color = context.accent;
    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          minY: lo - pad,
          maxY: hi + pad,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppTheme.ink,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '$prefix${_price(s.y, prefix)}\n${_axisTime(pts[s.x.toInt().clamp(0, pts.length - 1)].time)}',
                    GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.white),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].price)],
              isCurved: true,
              curveSmoothness: 0.15,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final prefix = _prefixFor(q, widget.category);
    final pts = _points;
    final rangeChange = (pts != null && pts.length > 1 && pts.first.price != 0)
        ? (pts.last.price - pts.first.price) / pts.first.price * 100
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(q.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, color: context.fg)),
              ),
              TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: context.surface, shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 20, color: context.fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(q.symbol, style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w700, color: context.fgMuted)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$prefix${_price(q.price, prefix)}',
                  style: GoogleFonts.urbanist(fontSize: 34, fontWeight: FontWeight.w700, color: context.fg)),
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: _changeChip(q.changePct)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('today', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: context.fgMuted)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _chart(context, prefix),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in ChartRange.values)
                  TapScale(
                    onTap: () {
                      if (r == _range) return;
                      setState(() => _range = r);
                      _loadChart();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: _range == r ? AppTheme.lime : context.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(r.label,
                          style: GoogleFonts.urbanist(
                              fontSize: 13, fontWeight: FontWeight.w800, color: _range == r ? AppTheme.ink : context.fgMuted)),
                    ),
                  ),
              ],
            ),
          ),
          if (rangeChange != null) ...[
            const SizedBox(height: 10),
            Text(
              '${rangeChange >= 0 ? '+' : ''}${rangeChange.toStringAsFixed(2)}% over ${_range.label}',
              style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w700, color: context.fgMuted),
            ),
          ],
          const SizedBox(height: 22),
          Text('Related news', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w700, color: context.fg)),
          const SizedBox(height: 6),
          if (_news == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: context.accent)),
            )
          else if (_news!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('No related news found.',
                  style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: context.fgMuted)),
            )
          else
            for (var i = 0; i < _news!.length; i++) ...[
              if (i > 0) Divider(color: context.border, height: 1),
              _NewsRow(item: _news![i]),
            ],
        ],
      ),
    );
  }
}
