import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class MarketQuote {
  final String symbol;
  final String name;
  final double price;
  final double changePct;
  final String? currency;
  final String? id;

  const MarketQuote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    this.currency,
    this.id,
  });

  bool get isUp => changePct >= 0;
}

class ChartPoint {
  final DateTime time;
  final double price;
  const ChartPoint(this.time, this.price);
}

enum ChartRange {
  day('1D', '1d', '5m', 1),
  week('1W', '5d', '30m', 7),
  month('1M', '1mo', '1d', 30),
  threeMonths('3M', '3mo', '1d', 90),
  year('1Y', '1y', '1d', 365),
  fiveYears('5Y', '5y', '1wk', 1825);

  final String label;
  final String yahooRange;
  final String yahooInterval;
  final int days;
  const ChartRange(this.label, this.yahooRange, this.yahooInterval, this.days);
}

class SymbolMatch {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String quoteType;
  const SymbolMatch({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    this.quoteType = '',
  });
}

class NewsItem {
  final String title;
  final String source;
  final String link;
  final DateTime? published;
  final String? thumbnail;
  final List<String> relatedSymbols;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    this.published,
    this.thumbnail,
    this.relatedSymbols = const [],
  });
}

/// Live market data. Crypto comes from CoinGecko, indices/commodities from
/// Yahoo Finance's public chart endpoint (routed through a public CORS relay
/// when running in a browser). News comes from Google News RSS via rss2json.
class MarketService {
  static const _indices = <(String, String)>[
    ('^NSEI', 'Nifty 50'),
    ('^BSESN', 'Sensex'),
    ('^GSPC', 'S&P 500'),
    ('^IXIC', 'Nasdaq'),
    ('GC=F', 'Gold'),
    ('CL=F', 'Crude Oil'),
  ];

  static const yahooHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  static Uri viaRelay(String target) {
    if (kIsWeb) {
      return Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}');
    }
    return Uri.parse(target);
  }

  static Uri _yahoo(String symbol, {String range = '1d', String interval = '1d'}) => viaRelay(
      'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(symbol)}?interval=$interval&range=$range');

  static Future<MarketQuote?> fetchQuote(String symbol, {String? name}) => _fetchIndex(symbol, name ?? symbol);

  static Future<List<MarketQuote>> fetchQuotes(List<(String, String?)> symbols) async {
    final results = await Future.wait(symbols.map((e) => fetchQuote(e.$1, name: e.$2)));
    return results.whereType<MarketQuote>().toList();
  }

  /// Keyless symbol lookup (stocks, ETFs, indices, crypto, forex) from Yahoo Finance.
  static Future<List<SymbolMatch>> searchSymbols(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final target = Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
      'q': q,
      'quotesCount': '$limit',
      'newsCount': '0',
    }).toString();
    try {
      final res = await http.get(viaRelay(target), headers: yahooHeaders).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final quotes = (jsonDecode(res.body)['quotes'] as List?) ?? [];
      return quotes
          .where((r) => r['symbol'] != null && (r['shortname'] ?? r['longname']) != null)
          .map((r) => SymbolMatch(
                symbol: r['symbol'] as String,
                name: (r['shortname'] ?? r['longname']) as String,
                exchange: (r['exchDisp'] ?? r['exchange'] ?? '') as String,
                type: (r['typeDisp'] ?? r['quoteType'] ?? '') as String,
                quoteType: (r['quoteType'] ?? '') as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Price history for any Yahoo symbol (stocks, indices, commodities, forex, crypto pairs like BTC-USD).
  static Future<List<ChartPoint>> fetchChart(String symbol, ChartRange range) async {
    try {
      final res = await http
          .get(_yahoo(symbol, range: range.yahooRange, interval: range.yahooInterval), headers: yahooHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final result = jsonDecode(res.body)['chart']['result'][0];
      final times = (result['timestamp'] as List?) ?? [];
      final closes = (result['indicators']['quote'][0]['close'] as List?) ?? [];
      final points = <ChartPoint>[];
      for (var i = 0; i < times.length && i < closes.length; i++) {
        final c = closes[i];
        if (c == null) continue;
        points.add(ChartPoint(DateTime.fromMillisecondsSinceEpoch((times[i] as int) * 1000), (c as num).toDouble()));
      }
      return points;
    } catch (_) {
      return [];
    }
  }

  /// Crypto price history from CoinGecko; [coinId] is MarketQuote.id (e.g. `bitcoin`).
  static Future<List<ChartPoint>> fetchCryptoChart(String coinId, String vsCurrency, ChartRange range) async {
    final uri = Uri.https('api.coingecko.com', '/api/v3/coins/$coinId/market_chart', {
      'vs_currency': vsCurrency,
      'days': '${range.days}',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final prices = (jsonDecode(res.body)['prices'] as List?) ?? [];
      return prices
          .map((p) => ChartPoint(DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()), (p[1] as num).toDouble()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<MarketQuote?> _fetchIndex(String symbol, String name) async {
    try {
      final res = await http.get(_yahoo(symbol), headers: yahooHeaders).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final meta = jsonDecode(res.body)['chart']['result'][0]['meta'];
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prev = ((meta['chartPreviousClose'] ?? meta['previousClose']) as num).toDouble();
      final pct = prev == 0 ? 0.0 : (price - prev) / prev * 100;
      return MarketQuote(
        symbol: symbol,
        name: name,
        price: price,
        changePct: pct,
        currency: meta['currency'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<MarketQuote>> fetchIndices() async {
    final results = await Future.wait(_indices.map((e) => _fetchIndex(e.$1, e.$2)));
    return results.whereType<MarketQuote>().toList();
  }

  /// Daily ECB reference rates for USD against major currencies (no key needed).
  static Future<List<MarketQuote>> fetchForex() async {
    const pairs = ['INR', 'EUR', 'GBP', 'JPY'];
    final start = DateTime.now().subtract(const Duration(days: 10));
    final from = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    try {
      final uri = Uri.parse('https://api.frankfurter.dev/v1/$from..?base=USD&symbols=${pairs.join(',')}');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final rates = Map<String, dynamic>.from(jsonDecode(res.body)['rates'] as Map);
      final days = rates.keys.toList()..sort();
      if (days.isEmpty) return [];
      final latest = Map<String, dynamic>.from(rates[days.last] as Map);
      final prev = days.length > 1 ? Map<String, dynamic>.from(rates[days[days.length - 2]] as Map) : latest;
      return [
        for (final c in pairs)
          if (latest[c] != null)
            MarketQuote(
              symbol: 'USD/$c',
              name: 'USD / $c',
              price: (latest[c] as num).toDouble(),
              changePct: prev[c] == null ? 0 : ((latest[c] as num) - (prev[c] as num)) / (prev[c] as num) * 100,
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// [vsCurrency] is a lowercase ISO code such as `inr` or `usd`.
  static Future<List<MarketQuote>> fetchCrypto(String vsCurrency, {int perPage = 10}) =>
      _coinMarkets(vsCurrency, {'per_page': '$perPage', 'page': '1'});

  static Future<List<MarketQuote>> fetchCryptoByIds(List<String> ids, String vsCurrency) =>
      _coinMarkets(vsCurrency, {'ids': ids.join(',')});

  static Future<List<MarketQuote>> _coinMarkets(String vsCurrency, Map<String, String> extra) async {
    final uri = Uri.https('api.coingecko.com', '/api/v3/coins/markets', {
      'vs_currency': vsCurrency,
      'order': 'market_cap_desc',
      'price_change_percentage': '24h',
      ...extra,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((c) {
        return MarketQuote(
          symbol: (c['symbol'] as String).toUpperCase(),
          name: c['name'] as String,
          price: (c['current_price'] as num).toDouble(),
          changePct: ((c['price_change_percentage_24h'] ?? 0) as num).toDouble(),
          currency: vsCurrency.toUpperCase(),
          id: c['id'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// News via Yahoo Finance's search endpoint, which returns a `news` array
  /// alongside symbol matches when `newsCount` > 0. [query] can be a free-text
  /// topic ("stock market", "crude oil") or a ticker ("AAPL", "^NSEI").
  static Future<List<NewsItem>> fetchYahooNews(String query, {int count = 10}) async {
    final target = Uri.https('query1.finance.yahoo.com', '/v1/finance/search', {
      'q': query,
      'quotesCount': '0',
      'newsCount': '$count',
    }).toString();
    try {
      final res = await http.get(viaRelay(target), headers: yahooHeaders).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final items = (jsonDecode(res.body)['news'] as List?) ?? [];
      return items.map((i) {
        final thumbs = (i['thumbnail']?['resolutions'] as List?) ?? [];
        final epoch = i['providerPublishTime'];
        return NewsItem(
          title: (i['title'] as String? ?? '').trim(),
          source: (i['publisher'] as String? ?? '').trim(),
          link: i['link'] as String? ?? '',
          published: epoch is num ? DateTime.fromMillisecondsSinceEpoch(epoch.toInt() * 1000) : null,
          thumbnail: thumbs.isNotEmpty ? thumbs.first['url'] as String? : null,
          relatedSymbols: ((i['relatedTickers'] as List?) ?? []).map((s) => s as String).toList(),
        );
      }).where((n) => n.title.isNotEmpty && n.link.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static const _newsTopics = ['stock market', 'markets', 'finance'];

  /// General market news for the main News tab: a few broad topics merged,
  /// de-duplicated by link, newest first.
  static Future<List<NewsItem>> fetchNews() async {
    final lists = await Future.wait(_newsTopics.map((t) => fetchYahooNews(t, count: 20)));
    final seen = <String>{};
    final all = lists.expand((l) => l).where((n) => seen.add(n.link)).toList()
      ..sort((a, b) => (b.published ?? DateTime(2000)).compareTo(a.published ?? DateTime(2000)));
    // Yahoo is often rate-limited or blocked in browsers; publisher feeds are a reliable fallback.
    if (all.isNotEmpty) return all.take(5).toList();
    return fetchPublisherNews();
  }

  static const _feeds = <(String, String)>[
    ('Economic Times', 'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms'),
    ('Mint', 'https://www.livemint.com/rss/markets'),
    ('BBC Business', 'https://feeds.bbci.co.uk/news/business/rss.xml'),
  ];

  static Future<List<NewsItem>> _fetchFeed(String source, String feedUrl) async {
    final uri = Uri.https('api.rss2json.com', '/v1/api.json', {'rss_url': feedUrl});
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      if (body['status'] != 'ok') return [];
      return ((body['items'] as List?) ?? []).map((i) {
        final raw = (i['pubDate'] as String? ?? '').trim();
        return NewsItem(
          title: (i['title'] as String? ?? '').trim(),
          source: source,
          link: i['link'] as String? ?? '',
          published: DateTime.tryParse('${raw.replaceFirst(' ', 'T')}Z'),
        );
      }).where((n) => n.title.isNotEmpty && n.link.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Economic Times, Mint and BBC Business headlines merged, newest first.
  static Future<List<NewsItem>> fetchPublisherNews() async {
    final lists = await Future.wait(_feeds.map((f) => _fetchFeed(f.$1, f.$2)));
    final all = lists.expand((l) => l).toList()
      ..sort((a, b) => (b.published ?? DateTime(2000)).compareTo(a.published ?? DateTime(2000)));
    return all.take(5).toList();
  }

  /// News for one symbol (e.g. a stock the user searched or added), or a
  /// market category label such as "crypto" / "forex" / "commodities".
  static Future<List<NewsItem>> fetchSymbolNews(String symbolOrTopic, {int count = 10}) =>
      fetchYahooNews(symbolOrTopic, count: count);
}
