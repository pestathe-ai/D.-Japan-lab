/// Indirizzi di ZenMarket e piccole funzioni sugli URL (senza plugin,
/// cosi' si possono testare in CI).
class Shop {
  const Shop(this.name, this.subtitle, this.path);
  final String name;
  final String subtitle;
  final String path;
}

class ZenUrls {
  static const String host = 'zenmarket.jp';
  static const String base = 'https://zenmarket.jp';

  /// Lingue offerte nelle impostazioni. '' = lascia decidere al sito.
  static const Map<String, String> languages = {
    '': 'Automatica (decide il sito)',
    'en': 'English',
  };

  static const List<Shop> shops = [
    Shop('Yahoo! Aste (JDirectItems)', 'Aste e oggetti usati', 'yahoo.aspx'),
    Shop('Mercari', 'Usato tra privati', 'mercari.aspx'),
    Shop('Rakuten', 'Negozi giapponesi', 'rakuten.aspx'),
    Shop('Amazon Japan', 'Nuovo', 'amazon.aspx'),
  ];

  static Uri page(String lang, String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final prefix = lang.isEmpty ? '' : '$lang/';
    return Uri.parse('$base/$prefix$clean');
  }

  static Uri home(String lang) => page(lang, '');
  static Uri cart(String lang) => page(lang, 'cart.aspx');
  static Uri account(String lang) => page(lang, 'profile/');

  /// Ricerca su ZenMarket. Funziona anche incollando il link di un
  /// prodotto (Mercari, Yahoo, Rakuten...): ZenMarket lo apre da solo.
  static Uri search(String lang, String query) =>
      page(lang, 'search.aspx').replace(queryParameters: {'q': query.trim()});

  static bool isZenMarket(Uri uri) =>
      uri.host == host || uri.host.endsWith('.$host');

  /// Schemi che la WebView deve aprire da sola; tutto il resto
  /// (mailto:, tel:, intent:, market:...) va passato ad Android.
  static bool opensInWebView(Uri uri) => const {
        'http',
        'https',
        'about',
        'data',
        'blob',
        'javascript',
      }.contains(uri.scheme.toLowerCase());

  /// Da un link "intent://..." estrae l'eventuale pagina web di riserva.
  static Uri? intentFallback(String raw) {
    final match = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(raw);
    if (match == null) return null;
    final decoded = Uri.decodeComponent(match.group(1)!);
    final uri = Uri.tryParse(decoded);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    return uri;
  }

  /// Se il testo e' (o contiene) un link web, lo restituisce.
  static Uri? extractLink(String text) {
    final match = RegExp(r'https?://[^\s<>"]+').firstMatch(text.trim());
    if (match == null) return null;
    return Uri.tryParse(match.group(0)!);
  }

  /// Cosa aprire per il testo scritto nella barra di ricerca.
  static Uri forInput(String lang, String input) {
    final link = extractLink(input);
    if (link != null && isZenMarket(link)) return link;
    return search(lang, link?.toString() ?? input);
  }

  /// Quale scheda della barra in basso evidenziare per questa pagina.
  /// 0 Home, 1 Negozi, 2 Cerca, 3 Carrello, 4 Account.
  static int tabFor(Uri? uri) {
    if (uri == null || !isZenMarket(uri)) return 0;
    final p = uri.path.toLowerCase();
    if (p.contains('cart')) return 3;
    if (p.contains('profile') || p.contains('account') || p.contains('login')) {
      return 4;
    }
    if (p.contains('search')) return 2;
    for (final s in shops) {
      if (p.endsWith(s.path)) return 1;
    }
    return 0;
  }
}
