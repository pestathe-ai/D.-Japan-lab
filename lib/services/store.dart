import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/models.dart';

/// Stato condiviso dell'app: preferiti e impostazioni, salvati sul telefono.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this._favorites, this._settings);

  static const _kFav = 'favorites_v1';
  static const _kSettings = 'settings_v1';

  final SharedPreferences _prefs;
  Favorites _favorites;
  AppSettings _settings;

  Favorites get favorites => _favorites;
  AppSettings get settings => _settings;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore._(
      prefs,
      Favorites.decode(prefs.getString(_kFav)),
      AppSettings.decode(prefs.getString(_kSettings)),
    );
  }

  Future<void> setFavorites(Favorites f) async {
    _favorites = f;
    notifyListeners();
    await _prefs.setString(_kFav, f.encode());
  }

  Future<void> setSettings(AppSettings s) async {
    _settings = s;
    notifyListeners();
    await _prefs.setString(_kSettings, s.encode());
  }

  /// Scarica il cambio JPY→EUR della BCE (servizio gratuito frankfurter).
  /// Restituisce null se non c'e' rete; in quel caso resta il valore salvato.
  Future<double?> refreshRate() async {
    const urls = [
      'https://api.frankfurter.dev/v1/latest?base=JPY&symbols=EUR',
      'https://api.frankfurter.app/latest?from=JPY&to=EUR',
    ];
    for (final u in urls) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client.getUrl(Uri.parse(u));
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final body = await res.transform(utf8.decoder).join();
        final rate = parseEurRate(body);
        if (rate != null) {
          await setSettings(_settings.copyWith(eurPerYen: rate, rateUpdatedAt: DateTime.now()));
          return rate;
        }
      } catch (_) {
        // prova il prossimo indirizzo
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }
}
