import 'package:flutter/material.dart';

import '../logic/cost_calculator.dart';
import '../logic/models.dart';
import '../logic/zen_urls.dart';
import '../services/store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store, required this.onClearSession});

  final AppStore store;
  final Future<void> Function() onClearSession;

  Future<void> _editNumber(
    BuildContext context, {
    required String title,
    required double current,
    required AppSettings Function(double v) apply,
    String? help,
  }) async {
    final ctrl = TextEditingController(
        text: current == current.roundToDouble() ? current.toStringAsFixed(0) : '$current'.replaceAll('.', ','));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(helperText: help, helperMaxLines: 3),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseNumber(ctrl.text)), child: const Text('Salva')),
        ],
      ),
    );
    if (v != null && v >= 0) await store.setSettings(apply(v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          return ListView(
            children: [
              const _Header('Sito'),
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Lingua del sito'),
                subtitle: Text(ZenUrls.languages[s.language] ?? s.language),
                onTap: () async {
                  final v = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Lingua del sito'),
                      children: [
                        for (final e in ZenUrls.languages.entries)
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, e.key),
                            child: Text(e.value),
                          ),
                      ],
                    ),
                  );
                  if (v != null) await store.setSettings(s.copyWith(language: v));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Esci e cancella dati del sito'),
                subtitle: const Text('Cookie, cache e accesso a ZenMarket'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancellare i dati del sito?'),
                      content: const Text('Dovrai rifare l\'accesso a ZenMarket. I preferiti restano.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancella')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await onClearSession();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
              const _Header('Calcolatore'),
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('Cambio 1 ¥ = … €'),
                subtitle: Text('${s.eurPerYen.toStringAsFixed(6)}'
                    '${s.rateUpdatedAt != null ? ' · aggiornato ${_date(s.rateUpdatedAt!)}' : ' · valore predefinito'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Aggiorna ora',
                  onPressed: () async {
                    final r = await store.refreshRate();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(r != null ? 'Cambio aggiornato' : 'Nessuna connessione')));
                  },
                ),
                onTap: () => _editNumber(context,
                    title: 'Cambio 1 ¥ in €', current: s.eurPerYen, apply: (v) => s.copyWith(eurPerYen: v)),
              ),
              _num(context, Icons.receipt_long, 'Commissione ZenMarket per articolo (¥)', s.serviceFeePerItemYen,
                  (v) => s.copyWith(serviceFeePerItemYen: v),
                  help: 'Controlla la tariffa attuale sul sito di ZenMarket.'),
              _num(context, Icons.credit_card, 'Commissione pagamento (%)', s.paymentFeePct,
                  (v) => s.copyWith(paymentFeePct: v),
                  help: 'Dipende dal metodo (carta, PayPal…). Metti 0 se non c\'e\'.'),
              _num(context, Icons.account_balance, 'IVA all\'importazione (%)', s.vatPct,
                  (v) => s.copyWith(vatPct: v), help: 'In Italia di solito 22%.'),
              _num(context, Icons.gavel, 'Dazi oltre 150 € (%)', s.dutyPct, (v) => s.copyWith(dutyPct: v),
                  help: 'Variano per tipo di merce. Si applicano solo se la merce supera 150 €.'),
              _num(context, Icons.local_shipping, 'Spese fisse corriere/dogana (€)', s.customsHandlingEur,
                  (v) => s.copyWith(customsHandlingEur: v),
                  help: 'Alcuni corrieri chiedono una tassa per lo sdoganamento.'),
              const _Header('Info'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('D. Japan Lab 0.1.0'),
                subtitle: Text('App non ufficiale: apre il sito zenmarket.jp. '
                    'Non e\' collegata a ZenMarket / ZenGroup Inc.'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _num(BuildContext context, IconData icon, String title, double value,
          AppSettings Function(double) apply, {String? help}) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value'),
        onTap: () => _editNumber(context, title: title, current: value, apply: apply, help: help),
      );

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );
}
