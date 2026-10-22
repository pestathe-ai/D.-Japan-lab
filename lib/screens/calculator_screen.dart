import 'package:flutter/material.dart';

import '../logic/cost_calculator.dart';
import '../services/store.dart';

/// Calcolatore: quanto costa davvero in euro, dogana compresa.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, required this.store, this.pagePrices = const []});

  final AppStore store;
  final List<int> pagePrices;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _item = TextEditingController();
  final _domestic = TextEditingController(text: '0');
  final _intl = TextEditingController(text: '0');
  final _qty = TextEditingController(text: '1');
  late final TextEditingController _rate;
  bool _updating = false;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(text: _fmtRate(store.settings.eurPerYen));
    if (widget.pagePrices.isNotEmpty) _item.text = '${widget.pagePrices.first}';
  }

  static String _fmtRate(double r) => r.toStringAsFixed(6).replaceAll('.', ',');

  double _n(TextEditingController c) => parseNumber(c.text) ?? 0;

  Future<void> _updateRate() async {
    setState(() => _updating = true);
    final r = await store.refreshRate();
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (r != null) _rate.text = _fmtRate(r);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r != null ? 'Cambio aggiornato' : 'Nessuna connessione: uso il cambio salvato'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    final res = calculateCost(CostInput(
      itemYen: _n(_item),
      domesticShippingYen: _n(_domestic),
      items: _n(_qty).round(),
      serviceFeePerItemYen: s.serviceFeePerItemYen,
      internationalShippingYen: _n(_intl),
      paymentFeePct: s.paymentFeePct,
      eurPerYen: _n(_rate),
      vatPct: s.vatPct,
      dutyPct: s.dutyPct,
      customsHandlingEur: s.customsHandlingEur,
    ));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calcola il costo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Totale stimato a casa', style: TextStyle(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Text(formatEur(res.totalEur),
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
                  Text('di cui dogana e IVA: ${formatEur(res.taxesEur)}',
                      style: TextStyle(color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.pagePrices.isNotEmpty) ...[
            const Text('Prezzi trovati nella pagina (tocca per usarlo):'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in widget.pagePrices)
                  ActionChip(
                    label: Text(formatYen(p.toDouble())),
                    onPressed: () => setState(() => _item.text = '$p'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _field(_item, 'Prezzo articolo (¥)'),
          _field(_domestic, 'Spedizione in Giappone (¥)'),
          _field(_qty, 'Numero di articoli'),
          _field(_intl, 'Spedizione internazionale (¥)',
              help: 'La vedi su ZenMarket quando spedisci il pacco'),
          Row(
            children: [
              Expanded(child: _field(_rate, 'Cambio: 1 ¥ = … €')),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Aggiorna cambio',
                onPressed: _updating ? null : _updateRate,
                icon: _updating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          const Divider(height: 32),
          _row('Commissione ZenMarket', formatYen(res.serviceFeeYen)),
          if (res.paymentFeeYen > 0) _row('Commissione pagamento', formatYen(res.paymentFeeYen)),
          _row('Paghi a ZenMarket', '${formatYen(res.paidToZenMarketYen)}  ≈ ${formatEur(res.paidToZenMarketEur)}'),
          _row('Valore in dogana', formatEur(res.customsValueEur)),
          if (res.dutyEur > 0) _row('Dazi', formatEur(res.dutyEur)),
          _row('IVA ${s.vatPct.toStringAsFixed(0)}%', formatEur(res.vatEur)),
          if (res.customsHandlingEur > 0) _row('Spese corriere/sdoganamento', formatEur(res.customsHandlingEur)),
          const SizedBox(height: 16),
          Text(
            'Stima indicativa. Commissioni, IVA e dazi si cambiano in Impostazioni. '
            'Il costo reale dipende da ZenMarket, dal corriere e dalla dogana.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {String? help}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, helperText: help, border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Flexible(child: Text(b, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}
