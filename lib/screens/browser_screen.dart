import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../logic/cost_calculator.dart';
import '../logic/models.dart';
import '../logic/zen_urls.dart';
import '../services/store.dart';
import 'calculator_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';

/// Schermata principale: il sito ZenMarket dentro l'app, con barra in basso.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _canGoBack = false;
  String _title = 'D. Japan Lab';
  Uri? _url;
  String? _error;

  AppStore get store => widget.store;
  String get _lang => store.settings.language;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (u) => setState(() {
          _error = null;
          _url = Uri.tryParse(u);
        }),
        onPageFinished: (_) => _refreshState(),
        onUrlChange: (change) {
          final u = change.url;
          if (u != null) setState(() => _url = Uri.tryParse(u));
          _refreshState();
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            setState(() => _error = e.description);
          }
        },
        onNavigationRequest: _onNavigation,
      ))
      ..loadRequest(ZenUrls.home(_lang));
    store.addListener(_onStore);
    // Aggiorna il cambio in silenzio all'avvio (se c'e' rete).
    store.refreshRate();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshState() async {
    final back = await _web.canGoBack();
    final title = await _web.getTitle();
    final url = await _web.currentUrl();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      if (title != null && title.trim().isNotEmpty) _title = title.trim();
      if (url != null) _url = Uri.tryParse(url);
    });
  }

  NavigationDecision _onNavigation(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null || ZenUrls.opensInWebView(uri)) {
      return NavigationDecision.navigate;
    }
    // mailto:, tel:, intent:, app esterne...
    if (uri.scheme == 'intent') {
      final fallback = ZenUrls.intentFallback(req.url);
      if (fallback != null) _web.loadRequest(fallback);
      return NavigationDecision.prevent;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    return NavigationDecision.prevent;
  }

  void _open(Uri uri) {
    setState(() => _error = null);
    _web.loadRequest(uri);
  }

  Future<void> _goBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  // ---------- Barra in basso ----------

  Future<void> _onTab(int i) async {
    switch (i) {
      case 0:
        _open(ZenUrls.home(_lang));
      case 1:
        _showShops();
      case 2:
        _showSearch();
      case 3:
        await _openSiteLink(r'cart', ZenUrls.cart(_lang));
      case 4:
        await _openSiteLink(r'profile|account|mypage', ZenUrls.account(_lang));
    }
  }

  /// Cerca nella pagina il link del sito che corrisponde (es. il carrello)
  /// e lo apre; se non lo trova, usa l'indirizzo di riserva.
  Future<void> _openSiteLink(String pattern, Uri fallback) async {
    final js = '''
(function(){
  var re = new RegExp('$pattern','i');
  var links = document.querySelectorAll('a[href]');
  for (var k = 0; k < links.length; k++) {
    var a = links[k];
    var h = a.href || '';
    if (h.indexOf('zenmarket.jp') < 0) continue;
    if (/logout|signout|help|faq/i.test(h)) continue;
    if (re.test(a.getAttribute('href'))) { window.location.href = h; return 'ok'; }
  }
  return 'none';
})();''';
    try {
      final onZen = _url != null && ZenUrls.isZenMarket(_url!);
      if (onZen) {
        final r = await _web.runJavaScriptReturningResult(js);
        if ('$r'.contains('ok')) return;
      }
    } catch (_) {
      // pagina non pronta: uso l'indirizzo di riserva
    }
    _open(fallback);
  }

  void _showShops() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Negozi giapponesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            for (final s in ZenUrls.shops)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(s.name),
                subtitle: Text(s.subtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _open(ZenUrls.page(_lang, s.path));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSearch() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final clipLink = ZenUrls.extractLink(clip?.text ?? '');
    if (!mounted) return;
    final ctrl = TextEditingController();
    final query = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cerca, o incolla un link Mercari/Yahoo…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            if (clipLink != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste),
                label: Text('Apri il link copiato\n${clipLink.host}',
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                onPressed: () => Navigator.pop(ctx, clipLink.toString()),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Cerca su ZenMarket'),
            ),
          ],
        ),
      ),
    );
    if (query == null || query.trim().isEmpty) return;
    _open(ZenUrls.forInput(_lang, query));
  }

  // ---------- Azioni in alto ----------

  bool get _isFavorite => _url != null && store.favorites.contains(_url.toString());

  Future<void> _toggleFavorite() async {
    final u = _url;
    if (u == null) return;
    final was = _isFavorite;
    await store.setFavorites(store.favorites
        .toggle(Favorite(title: _title, url: u.toString(), addedAt: DateTime.now())));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(was ? 'Tolto dai preferiti' : 'Aggiunto ai preferiti'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openCalculator() async {
    String pageText = '';
    try {
      final r = await _web.runJavaScriptReturningResult(
          '(document.body ? document.body.innerText : "").substring(0, 20000)');
      pageText = '$r';
    } catch (_) {}
    if (!mounted) return;
    final prices = extractYenPrices(pageText.replaceAll(r'\n', '\n'));
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CalculatorScreen(store: store, pagePrices: prices),
      ),
    );
  }

  Future<void> _onMenu(String v) async {
    final u = _url;
    switch (v) {
      case 'favorites':
        final picked = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => FavoritesScreen(store: store)),
        );
        if (picked != null) {
          final p = Uri.tryParse(picked);
          if (p != null) _open(p);
        }
      case 'copy':
        if (u != null) {
          await Clipboard.setData(ClipboardData(text: u.toString()));
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Link copiato')));
        }
      case 'browser':
        if (u != null) {
          await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
        }
      case 'reload':
        await _web.reload();
      case 'forward':
        if (await _web.canGoForward()) await _web.goForward();
      case 'settings':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              store: store,
              onClearSession: () async {
                await WebViewCookieManager().clearCookies();
                await _web.clearCache();
                await _web.clearLocalStorage();
                _open(ZenUrls.home(_lang));
              },
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: _canGoBack
              ? IconButton(
                  tooltip: 'Indietro',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
              : const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('🗾', style: TextStyle(fontSize: 22)),
                ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16)),
              if (_url != null)
                Text(_url!.host, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Calcola costo in euro',
              icon: const Icon(Icons.currency_yen),
              onPressed: _openCalculator,
            ),
            IconButton(
              tooltip: _isFavorite ? 'Togli dai preferiti' : 'Aggiungi ai preferiti',
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              onPressed: _toggleFavorite,
            ),
            PopupMenuButton<String>(
              onSelected: _onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'favorites', child: ListTile(leading: Icon(Icons.bookmarks_outlined), title: Text('Preferiti'))),
                PopupMenuItem(value: 'reload', child: ListTile(leading: Icon(Icons.refresh), title: Text('Ricarica'))),
                PopupMenuItem(value: 'forward', child: ListTile(leading: Icon(Icons.arrow_forward), title: Text('Avanti'))),
                PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.link), title: Text('Copia link'))),
                PopupMenuItem(value: 'browser', child: ListTile(leading: Icon(Icons.open_in_browser), title: Text('Apri nel browser'))),
                PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Impostazioni'))),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _progress < 100
                ? LinearProgressIndicator(value: _progress / 100, minHeight: 3)
                : const SizedBox(height: 3),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _web),
            if (_error != null) _ErrorPanel(message: _error!, onRetry: () {
              setState(() => _error = null);
              _web.reload();
            }),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: ZenUrls.tabFor(_url),
          onDestinationSelected: _onTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Negozi'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Cerca'),
            NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Carrello'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 12),
                const Text('Pagina non raggiungibile', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Riprova')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
