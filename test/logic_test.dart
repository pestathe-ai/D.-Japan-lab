import 'package:d_japan_lab/logic/cost_calculator.dart';
import 'package:d_japan_lab/logic/models.dart';
import 'package:d_japan_lab/logic/zen_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZenUrls', () {
    test('pagine con e senza lingua', () {
      expect(ZenUrls.home('').toString(), 'https://zenmarket.jp/');
      expect(ZenUrls.cart('en').toString(), 'https://zenmarket.jp/en/cart.aspx');
      expect(ZenUrls.page('', '/mercari.aspx').toString(), 'https://zenmarket.jp/mercari.aspx');
    });

    test('ricerca codifica il testo', () {
      final u = ZenUrls.search('', ' gundam rx-78 ');
      expect(u.path, '/search.aspx');
      expect(u.queryParameters['q'], 'gundam rx-78');
    });

    test('link incollato: Mercari va in ricerca, ZenMarket si apre diretto', () {
      final m = ZenUrls.forInput('', 'guarda https://jp.mercari.com/item/m123 bello');
      expect(m.queryParameters['q'], 'https://jp.mercari.com/item/m123');
      final z = ZenUrls.forInput('', 'https://zenmarket.jp/en/auction.aspx?itemCode=x1');
      expect(z.host, 'zenmarket.jp');
      expect(z.path, '/en/auction.aspx');
    });

    test('schemi gestiti dalla WebView', () {
      expect(ZenUrls.opensInWebView(Uri.parse('https://paypal.com')), isTrue);
      expect(ZenUrls.opensInWebView(Uri.parse('mailto:a@b.it')), isFalse);
      expect(ZenUrls.opensInWebView(Uri.parse('intent://x#Intent;end')), isFalse);
    });

    test('intent con pagina di riserva', () {
      const raw = 'intent://scan/#Intent;scheme=zxing;S.browser_fallback_url=https%3A%2F%2Fexample.com%2Fa;end';
      expect(ZenUrls.intentFallback(raw).toString(), 'https://example.com/a');
      expect(ZenUrls.intentFallback('intent://x#Intent;end'), isNull);
    });

    test('scheda evidenziata', () {
      expect(ZenUrls.tabFor(Uri.parse('https://zenmarket.jp/en/cart.aspx')), 3);
      expect(ZenUrls.tabFor(Uri.parse('https://zenmarket.jp/profile/orders.aspx')), 4);
      expect(ZenUrls.tabFor(Uri.parse('https://zenmarket.jp/mercari.aspx')), 1);
      expect(ZenUrls.tabFor(Uri.parse('https://zenmarket.jp/search.aspx?q=a')), 2);
      expect(ZenUrls.tabFor(Uri.parse('https://www.paypal.com/x')), 0);
      expect(ZenUrls.tabFor(null), 0);
    });
  });

  group('calcolatore', () {
    test('caso base senza dazi', () {
      final r = calculateCost(const CostInput(
        itemYen: 10000,
        domesticShippingYen: 700,
        internationalShippingYen: 3000,
        eurPerYen: 0.006,
      ));
      expect(r.serviceFeeYen, 300);
      expect(r.paidToZenMarketYen, 14000);
      expect(r.paidToZenMarketEur, closeTo(84.0, 1e-9));
      expect(r.customsValueEur, closeTo(82.2, 1e-9));
      expect(r.dutyEur, 0);
      expect(r.vatEur, closeTo(18.084, 1e-9));
      expect(r.totalEur, closeTo(102.084, 1e-9));
    });

    test('dazi solo oltre 150 € di merce', () {
      final r = calculateCost(const CostInput(
        itemYen: 40000,
        internationalShippingYen: 5000,
        eurPerYen: 0.006,
        dutyPct: 4,
        paymentFeePct: 3,
        items: 2,
        customsHandlingEur: 5,
      ));
      expect(r.serviceFeeYen, 600);
      expect(r.paymentFeeYen, closeTo(45600 * 0.03, 1e-9));
      expect(r.customsValueEur, closeTo(270, 1e-9));
      expect(r.dutyEur, closeTo(10.8, 1e-9));
      expect(r.vatEur, closeTo((270 + 10.8) * 0.22, 1e-9));
      expect(r.totalEur, closeTo(r.paidToZenMarketEur + 10.8 + r.vatEur + 5, 1e-9));
    });

    test('valori assurdi diventano zero', () {
      final r = calculateCost(const CostInput(itemYen: -5, eurPerYen: double.nan, items: 0));
      expect(r.totalEur, 0);
      expect(r.serviceFeeYen, 300);
    });

    test('lettura numeri all\'italiana', () {
      expect(parseNumber('12.500'), 12500);
      expect(parseNumber('12,500'), 12500);
      expect(parseNumber('1.234,56'), 1234.56);
      expect(parseNumber('0,0061'), 0.0061);
      expect(parseNumber('0.006'), 0.006);
      expect(parseNumber('¥ 3.000'), 3000);
      expect(parseNumber('22'), 22);
      expect(parseNumber('1,5'), 1.5);
      expect(parseNumber(''), isNull);
      expect(parseNumber('abc'), isNull);
    });

    test('prezzi trovati nel testo della pagina', () {
      const text = 'Price: ¥12,500 (approx) Shipping 700円  Bid 12,500 JPY  total ￥ 980 and 3 items';
      expect(extractYenPrices(text), [12500, 700, 980]);
      expect(extractYenPrices('nessun prezzo qui 42'), isEmpty);
    });

    test('formattazione', () {
      expect(formatEur(1234.5), '€ 1.234,50');
      expect(formatEur(0.4), '€ 0,40');
      expect(formatYen(1234567), '¥ 1.234.567');
    });
  });

  group('preferiti e impostazioni', () {
    test('aggiungi, sposta in cima, togli', () {
      final a = Favorite(title: 'A', url: 'https://zenmarket.jp/a', addedAt: DateTime(2026));
      final b = Favorite(title: 'B', url: 'https://zenmarket.jp/b', addedAt: DateTime(2026));
      var f = Favorites().add(a).add(b);
      expect(f.items.map((e) => e.title), ['B', 'A']);
      f = f.add(Favorite(title: 'A2', url: 'https://zenmarket.jp/a/', addedAt: DateTime(2026)));
      expect(f.items.map((e) => e.title), ['A2', 'B']);
      expect(f.contains('http://zenmarket.jp/b'), isTrue);
      f = f.toggle(b);
      expect(f.items.length, 1);
    });

    test('salvataggio e ricarica', () {
      final f = Favorites().add(Favorite(title: 'X', url: 'https://zenmarket.jp/x', addedAt: DateTime(2026, 5, 1)));
      final back = Favorites.decode(f.encode());
      expect(back.items.single.title, 'X');
      expect(back.items.single.addedAt, DateTime(2026, 5, 1));
      expect(Favorites.decode('rotto{').items, isEmpty);
      expect(Favorites.decode(null).items, isEmpty);
    });

    test('impostazioni con valori mancanti o sbagliati', () {
      final s = const AppSettings().copyWith(vatPct: 10, language: 'en', eurPerYen: 0.0059);
      final back = AppSettings.decode(s.encode());
      expect(back.vatPct, 10);
      expect(back.language, 'en');
      expect(back.eurPerYen, 0.0059);
      final bad = AppSettings.decode('{"vatPct": -3, "serviceFeePerItemYen": "x"}');
      expect(bad.vatPct, 22);
      expect(bad.serviceFeePerItemYen, 300);
    });

    test('risposta del servizio di cambio', () {
      expect(parseEurRate('{"amount":1.0,"base":"JPY","rates":{"EUR":0.00598}}'), 0.00598);
      expect(parseEurRate('{"rates":{}}'), isNull);
      expect(parseEurRate('<html>'), isNull);
    });
  });
}
