import 'dart:convert';
import 'package:http/http.dart' as http;
import 'market_service.dart';

enum MarketCategory {
  india('Indian market'),
  us('US market'),
  crypto('Crypto'),
  forex('Forex'),
  commodities('Commodities');

  final String label;
  const MarketCategory(this.label);
}

/// Top daily movers per market tab, plus per-tab search. Stocks, forex and
/// commodities use Yahoo's batched spark endpoint; crypto uses CoinGecko.
class MarketMoversService {
  static const moversCount = 10;
  static const _cacheTtl = Duration(minutes: 1);
  static final _cache = <String, (DateTime, List<MarketQuote>)>{};

  static const _nifty = <String, String>{
    'RELIANCE.NS': 'Reliance Industries', 'TCS.NS': 'TCS', 'HDFCBANK.NS': 'HDFC Bank', 'INFY.NS': 'Infosys',
    'ICICIBANK.NS': 'ICICI Bank', 'HINDUNILVR.NS': 'Hindustan Unilever', 'ITC.NS': 'ITC', 'SBIN.NS': 'State Bank of India',
    'BHARTIARTL.NS': 'Bharti Airtel', 'KOTAKBANK.NS': 'Kotak Mahindra Bank', 'LT.NS': 'Larsen & Toubro',
    'AXISBANK.NS': 'Axis Bank', 'ASIANPAINT.NS': 'Asian Paints', 'MARUTI.NS': 'Maruti Suzuki', 'SUNPHARMA.NS': 'Sun Pharma',
    'TITAN.NS': 'Titan', 'BAJFINANCE.NS': 'Bajaj Finance', 'WIPRO.NS': 'Wipro', 'HCLTECH.NS': 'HCL Tech',
    'ULTRACEMCO.NS': 'UltraTech Cement', 'NESTLEIND.NS': 'Nestle India', 'ONGC.NS': 'ONGC', 'NTPC.NS': 'NTPC',
    'POWERGRID.NS': 'Power Grid', 'TATAMOTORS.NS': 'Tata Motors', 'TATASTEEL.NS': 'Tata Steel', 'M&M.NS': 'Mahindra & Mahindra',
    'JSWSTEEL.NS': 'JSW Steel', 'ADANIENT.NS': 'Adani Enterprises', 'ADANIPORTS.NS': 'Adani Ports', 'COALINDIA.NS': 'Coal India',
    'TECHM.NS': 'Tech Mahindra', 'INDUSINDBK.NS': 'IndusInd Bank', 'BAJAJFINSV.NS': 'Bajaj Finserv', 'GRASIM.NS': 'Grasim',
    'CIPLA.NS': 'Cipla', 'DRREDDY.NS': "Dr. Reddy's", 'EICHERMOT.NS': 'Eicher Motors', 'HEROMOTOCO.NS': 'Hero MotoCorp',
    'BRITANNIA.NS': 'Britannia', 'DIVISLAB.NS': "Divi's Labs", 'APOLLOHOSP.NS': 'Apollo Hospitals', 'HINDALCO.NS': 'Hindalco',
    'BPCL.NS': 'BPCL', 'TATACONSUM.NS': 'Tata Consumer', 'SBILIFE.NS': 'SBI Life', 'HDFCLIFE.NS': 'HDFC Life',
    'BAJAJ-AUTO.NS': 'Bajaj Auto', 'LTIM.NS': 'LTIMindtree', 'SHRIRAMFIN.NS': 'Shriram Finance',
  };

  static const _us = <String, String>{
    'AAPL': 'Apple', 'MSFT': 'Microsoft', 'NVDA': 'NVIDIA', 'AMZN': 'Amazon', 'GOOGL': 'Alphabet', 'META': 'Meta',
    'TSLA': 'Tesla', 'BRK-B': 'Berkshire Hathaway', 'AVGO': 'Broadcom', 'JPM': 'JPMorgan Chase', 'LLY': 'Eli Lilly',
    'V': 'Visa', 'UNH': 'UnitedHealth', 'XOM': 'Exxon Mobil', 'MA': 'Mastercard', 'COST': 'Costco', 'HD': 'Home Depot',
    'PG': 'Procter & Gamble', 'JNJ': 'Johnson & Johnson', 'NFLX': 'Netflix', 'ABBV': 'AbbVie', 'BAC': 'Bank of America',
    'CRM': 'Salesforce', 'ORCL': 'Oracle', 'AMD': 'AMD', 'KO': 'Coca-Cola', 'PEP': 'PepsiCo', 'WMT': 'Walmart',
    'CVX': 'Chevron', 'MRK': 'Merck', 'ADBE': 'Adobe', 'CSCO': 'Cisco', 'TMO': 'Thermo Fisher', 'ACN': 'Accenture',
    'MCD': "McDonald's", 'DIS': 'Disney', 'INTC': 'Intel', 'QCOM': 'Qualcomm', 'IBM': 'IBM', 'GE': 'GE Aerospace',
    'CAT': 'Caterpillar', 'PFE': 'Pfizer', 'NKE': 'Nike', 'UBER': 'Uber', 'PYPL': 'PayPal', 'PLTR': 'Palantir',
    'COIN': 'Coinbase', 'SHOP': 'Shopify', 'SNOW': 'Snowflake', 'BA': 'Boeing',
  };

  static const _forex = <String, String>{
    'EURUSD=X': 'EUR / USD', 'GBPUSD=X': 'GBP / USD', 'JPY=X': 'USD / JPY', 'INR=X': 'USD / INR', 'AUDUSD=X': 'AUD / USD',
    'NZDUSD=X': 'NZD / USD', 'CAD=X': 'USD / CAD', 'CHF=X': 'USD / CHF', 'CNY=X': 'USD / CNY', 'SGD=X': 'USD / SGD',
    'HKD=X': 'USD / HKD', 'KRW=X': 'USD / KRW', 'MXN=X': 'USD / MXN', 'BRL=X': 'USD / BRL', 'ZAR=X': 'USD / ZAR',
    'TRY=X': 'USD / TRY', 'EURINR=X': 'EUR / INR', 'GBPINR=X': 'GBP / INR', 'JPYINR=X': 'JPY / INR', 'AEDINR=X': 'AED / INR',
    'EURGBP=X': 'EUR / GBP', 'EURJPY=X': 'EUR / JPY', 'GBPJPY=X': 'GBP / JPY', 'AUDJPY=X': 'AUD / JPY',
  };

  static const _commodities = <String, String>{
    'GC=F': 'Gold', 'SI=F': 'Silver', 'PL=F': 'Platinum', 'PA=F': 'Palladium', 'HG=F': 'Copper', 'CL=F': 'Crude Oil (WTI)',
    'BZ=F': 'Brent Crude', 'NG=F': 'Natural Gas', 'RB=F': 'Gasoline', 'HO=F': 'Heating Oil', 'ZC=F': 'Corn',
    'ZW=F': 'Wheat', 'ZS=F': 'Soybeans', 'ZL=F': 'Soybean Oil', 'KC=F': 'Coffee', 'SB=F': 'Sugar', 'CC=F': 'Cocoa',
    'CT=F': 'Cotton', 'OJ=F': 'Orange Juice', 'LE=F': 'Live Cattle', 'HE=F': 'Lean Hogs', 'LBS=F': 'Lumber',
  };

  static Map<String, String> _universe(MarketCategory c) => switch (c) {
        MarketCategory.india => _nifty,
        MarketCategory.us => _us,
        MarketCategory.forex => _forex,
        MarketCategory.commodities => _commodities,
        MarketCategory.crypto => const {},
      };

  /// One batched request returns the day's price and % change for many symbols.
  static Future<List<MarketQuote>> _spark(Map<String, String> names) async {
    final symbols = names.keys.toList();
    final chunks = <List<String>>[
      for (var i = 0; i < symbols.length; i += 20) symbols.sublist(i, (i + 20).clamp(0, symbols.length)),
    ];
    final parts = await Future.wait(chunks.map((chunk) async {
      final target = Uri.https('query1.finance.yahoo.com', '/v8/finance/spark', {
        'symbols': chunk.join(','),
        'range': '1d',
        'interval': '1d',
      }).toString();
      try {
        final res = await http
            .get(MarketService.viaRelay(target), headers: MarketService.yahooHeaders)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) return <MarketQuote>[];
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final out = <MarketQuote>[];
        for (final e in body.entries) {
          final v = e.value;
          if (v is! Map || v['fulldayPrice'] == null || v['fulldayChangePercent'] == null) continue;
          out.add(MarketQuote(
            symbol: e.key,
            name: names[e.key] ?? e.key,
            price: (v['fulldayPrice'] as num).toDouble(),
            changePct: (v['fulldayChangePercent'] as num).toDouble(),
          ));
        }
        return out;
      } catch (_) {
        return <MarketQuote>[];
      }
    }));
    return parts.expand((l) => l).toList();
  }

  static List<MarketQuote> _topMovers(List<MarketQuote> all) =>
      (all.toList()..sort((a, b) => b.changePct.abs().compareTo(a.changePct.abs()))).take(moversCount).toList();

  /// Top 10 movers of the day (largest absolute % change) for one tab.
  static Future<List<MarketQuote>> fetchTopMovers(MarketCategory category, {String vsCurrency = 'usd'}) async {
    final key = '${category.name}:$vsCurrency';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < _cacheTtl) return hit.$2;

    final all = category == MarketCategory.crypto
        ? await MarketService.fetchCrypto(vsCurrency, perPage: 100)
        : await _spark(_universe(category));
    final movers = _topMovers(all);
    if (movers.isNotEmpty) _cache[key] = (DateTime.now(), movers);
    return movers;
  }

  /// All tabs at once, for the first-glance screen.
  static Future<Map<MarketCategory, List<MarketQuote>>> fetchAllMovers({String vsCurrency = 'usd'}) async {
    final lists = await Future.wait(MarketCategory.values.map((c) => fetchTopMovers(c, vsCurrency: vsCurrency)));
    return {for (var i = 0; i < lists.length; i++) MarketCategory.values[i]: lists[i]};
  }

  static const _indiaExchanges = {'NSI', 'BSE'};

  static bool _matches(MarketCategory c, SymbolMatch m) => switch (c) {
        MarketCategory.india => _indiaExchanges.contains(m.exchange) ||
            m.symbol.endsWith('.NS') ||
            m.symbol.endsWith('.BO') ||
            m.symbol == '^NSEI' ||
            m.symbol == '^BSESN',
        MarketCategory.us => {'EQUITY', 'ETF'}.contains(m.quoteType) && !m.symbol.contains('.') && !m.symbol.contains('=') ||
            m.symbol.startsWith('^') && !m.symbol.endsWith('NSEI') && !m.symbol.endsWith('BSESN'),
        MarketCategory.forex => m.quoteType == 'CURRENCY',
        MarketCategory.commodities => m.quoteType == 'FUTURE',
        MarketCategory.crypto => false,
      };

  /// Search inside one tab; returns priced quotes (empty for blank queries).
  static Future<List<MarketQuote>> search(MarketCategory category, String query, {String vsCurrency = 'usd'}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    if (category == MarketCategory.crypto) return _searchCrypto(q, vsCurrency);
    final matches = (await MarketService.searchSymbols(q, limit: 20)).where((m) => _matches(category, m)).take(10).toList();
    if (matches.isEmpty) return [];
    return _spark({for (final m in matches) m.symbol: m.name});
  }

  static Future<List<MarketQuote>> _searchCrypto(String q, String vs) async {
    try {
      final res = await http
          .get(Uri.https('api.coingecko.com', '/api/v3/search', {'query': q}))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final ids = ((jsonDecode(res.body)['coins'] as List?) ?? []).take(10).map((c) => c['id'] as String).toList();
      if (ids.isEmpty) return [];
      return await MarketService.fetchCryptoByIds(ids, vs);
    } catch (_) {
      return [];
    }
  }
}
