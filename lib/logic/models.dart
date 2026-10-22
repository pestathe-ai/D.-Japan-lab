import 'dart:convert';

/// Pagina salvata nei preferiti.
class Favorite {
  const Favorite({required this.title, required this.url, required this.addedAt});

  final String title;
  final String url;
  final DateTime addedAt;

  Map<String, dynamic> toJson() =>
      {'title': title, 'url': url, 'addedAt': addedAt.toIso8601String()};

  static Favorite? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    if (url is! String || url.isEmpty) return null;
    final title = raw['title'];
    return Favorite(
      title: title is String && title.trim().isNotEmpty ? title.trim() : url,
      url: url,
      addedAt: DateTime.tryParse('${raw['addedAt']}') ?? DateTime(2026),
    );
  }
}

class Favorites {
  Favorites([List<Favorite>? items]) : items = List.unmodifiable(items ?? const []);

  final List<Favorite> items;

  bool contains(String url) => items.any((f) => _same(f.url, url));

  /// Aggiunge in cima; se c'era gia', lo sposta in cima col nuovo titolo.
  Favorites add(Favorite fav) =>
      Favorites([fav, ...items.where((f) => !_same(f.url, fav.url))]);

  Favorites remove(String url) =>
      Favorites(items.where((f) => !_same(f.url, url)).toList());

  Favorites toggle(Favorite fav) => contains(fav.url) ? remove(fav.url) : add(fav);

  String encode() => jsonEncode(items.map((f) => f.toJson()).toList());

  static Favorites decode(String? raw) {
    if (raw == null || raw.isEmpty) return Favorites();
    try {
      final list = jsonDecode(raw);
      if (list is! List) return Favorites();
      return Favorites(list.map(Favorite.fromJson).whereType<Favorite>().toList());
    } catch (_) {
      return Favorites();
    }
  }

  static bool _same(String a, String b) => _norm(a) == _norm(b);
  static String _norm(String u) {
    var s = u.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.replaceFirst(RegExp(r'^http://'), 'https://');
  }
}

/// Impostazioni dell'app (valori predefiniti modificabili dall'utente).
class AppSettings {
  const AppSettings({
    this.language = '',
    this.eurPerYen = 0.0060,
    this.rateUpdatedAt,
    this.serviceFeePerItemYen = 300,
    this.paymentFeePct = 0,
    this.vatPct = 22,
    this.dutyPct = 0,
    this.customsHandlingEur = 0,
  });

  final String language;
  final double eurPerYen;
  final DateTime? rateUpdatedAt;
  final double serviceFeePerItemYen;
  final double paymentFeePct;
  final double vatPct;
  final double dutyPct;
  final double customsHandlingEur;

  AppSettings copyWith({
    String? language,
    double? eurPerYen,
    DateTime? rateUpdatedAt,
    double? serviceFeePerItemYen,
    double? paymentFeePct,
    double? vatPct,
    double? dutyPct,
    double? customsHandlingEur,
  }) =>
      AppSettings(
        language: language ?? this.language,
        eurPerYen: eurPerYen ?? this.eurPerYen,
        rateUpdatedAt: rateUpdatedAt ?? this.rateUpdatedAt,
        serviceFeePerItemYen: serviceFeePerItemYen ?? this.serviceFeePerItemYen,
        paymentFeePct: paymentFeePct ?? this.paymentFeePct,
        vatPct: vatPct ?? this.vatPct,
        dutyPct: dutyPct ?? this.dutyPct,
        customsHandlingEur: customsHandlingEur ?? this.customsHandlingEur,
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'eurPerYen': eurPerYen,
        'rateUpdatedAt': rateUpdatedAt?.toIso8601String(),
        'serviceFeePerItemYen': serviceFeePerItemYen,
        'paymentFeePct': paymentFeePct,
        'vatPct': vatPct,
        'dutyPct': dutyPct,
        'customsHandlingEur': customsHandlingEur,
      };

  static AppSettings decode(String? raw) {
    const d = AppSettings();
    if (raw == null || raw.isEmpty) return d;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return d;
      double num(String k, double def) {
        final v = m[k];
        return v is num && v.isFinite && v >= 0 ? v.toDouble() : def;
      }

      final lang = m['language'];
      return AppSettings(
        language: lang is String ? lang : d.language,
        eurPerYen: num('eurPerYen', d.eurPerYen),
        rateUpdatedAt: DateTime.tryParse('${m['rateUpdatedAt']}'),
        serviceFeePerItemYen: num('serviceFeePerItemYen', d.serviceFeePerItemYen),
        paymentFeePct: num('paymentFeePct', d.paymentFeePct),
        vatPct: num('vatPct', d.vatPct),
        dutyPct: num('dutyPct', d.dutyPct),
        customsHandlingEur: num('customsHandlingEur', d.customsHandlingEur),
      );
    } catch (_) {
      return d;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Legge la risposta JSON del servizio di cambio (frankfurter).
double? parseEurRate(String body) {
  try {
    final m = jsonDecode(body);
    if (m is! Map) return null;
    final rates = m['rates'];
    if (rates is! Map) return null;
    final v = rates['EUR'];
    if (v is num && v > 0) return v.toDouble();
    return null;
  } catch (_) {
    return null;
  }
}
