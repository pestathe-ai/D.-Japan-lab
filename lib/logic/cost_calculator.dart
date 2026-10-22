/// Calcolo del costo finale di un acquisto dal Giappone, arrivato in Italia.
/// Tutto in Dart puro: nessun plugin, testabile in CI.
class CostInput {
  const CostInput({
    required this.itemYen,
    this.domesticShippingYen = 0,
    this.items = 1,
    this.serviceFeePerItemYen = 300,
    this.internationalShippingYen = 0,
    this.paymentFeePct = 0,
    required this.eurPerYen,
    this.vatPct = 22,
    this.dutyPct = 0,
    this.dutyFreeThresholdEur = 150,
    this.customsHandlingEur = 0,
  });

  final double itemYen;
  final double domesticShippingYen;
  final int items;
  final double serviceFeePerItemYen;
  final double internationalShippingYen;
  final double paymentFeePct;
  final double eurPerYen;
  final double vatPct;
  final double dutyPct;
  final double dutyFreeThresholdEur;
  final double customsHandlingEur;
}

class CostResult {
  const CostResult({
    required this.serviceFeeYen,
    required this.paymentFeeYen,
    required this.paidToZenMarketYen,
    required this.paidToZenMarketEur,
    required this.customsValueEur,
    required this.dutyEur,
    required this.vatEur,
    required this.customsHandlingEur,
    required this.totalEur,
  });

  final double serviceFeeYen;
  final double paymentFeeYen;
  final double paidToZenMarketYen;
  final double paidToZenMarketEur;

  /// Valore su cui la dogana calcola le tasse (merce + spedizioni).
  final double customsValueEur;
  final double dutyEur;
  final double vatEur;
  final double customsHandlingEur;

  /// Quanto spendi in tutto, compresa la dogana.
  final double totalEur;

  double get taxesEur => dutyEur + vatEur + customsHandlingEur;
}

CostResult calculateCost(CostInput i) {
  double nn(double v) => v.isFinite && v > 0 ? v : 0;

  final items = i.items < 1 ? 1 : i.items;
  final item = nn(i.itemYen);
  final domestic = nn(i.domesticShippingYen);
  final intl = nn(i.internationalShippingYen);
  final rate = nn(i.eurPerYen);

  final serviceFee = nn(i.serviceFeePerItemYen) * items;
  final beforePayment = item + domestic + serviceFee + intl;
  final paymentFee = beforePayment * nn(i.paymentFeePct) / 100;
  final paidYen = beforePayment + paymentFee;
  final paidEur = paidYen * rate;

  // In dogana conta il valore della merce + le spedizioni,
  // non le commissioni del servizio.
  final customsValue = (item + domestic + intl) * rate;
  final goodsValue = (item + domestic) * rate;
  final duty =
      goodsValue > nn(i.dutyFreeThresholdEur) ? customsValue * nn(i.dutyPct) / 100 : 0.0;
  final vat = (customsValue + duty) * nn(i.vatPct) / 100;
  final handling = nn(i.customsHandlingEur);

  return CostResult(
    serviceFeeYen: serviceFee,
    paymentFeeYen: paymentFee,
    paidToZenMarketYen: paidYen,
    paidToZenMarketEur: paidEur,
    customsValueEur: customsValue,
    dutyEur: duty,
    vatEur: vat,
    customsHandlingEur: handling,
    totalEur: paidEur + duty + vat + handling,
  );
}

/// Legge un numero scritto come "12.500", "12,500", "1.234,56" o "0,0061".
double? parseNumber(String text) {
  var s = text.trim().replaceAll(RegExp(r'[\s¥€円]'), '');
  if (s.isEmpty) return null;
  final hasDot = s.contains('.');
  final hasComma = s.contains(',');
  if (hasDot && hasComma) {
    // L'ultimo separatore e' quello dei decimali.
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (hasComma) {
    final parts = s.split(',');
    final thousands = parts.length > 1 &&
        parts.skip(1).every((p) => p.length == 3) &&
        !s.startsWith('0,');
    s = thousands ? parts.join() : s.replaceAll(',', '.');
  } else if (hasDot) {
    final parts = s.split('.');
    final thousands = parts.length > 2 ||
        (parts.length == 2 && parts[1].length == 3 && !s.startsWith('0.'));
    if (thousands) s = parts.join();
  }
  return double.tryParse(s);
}

/// Cerca nel testo di una pagina i prezzi in yen ("¥12,500", "12,500円",
/// "12500 JPY", "12,500 yen"). Restituisce valori unici, nell'ordine trovato.
List<int> extractYenPrices(String text, {int max = 6}) {
  final patterns = [
    RegExp(r'[¥￥]\s?(\d{1,3}(?:[,.]\d{3})+|\d+)'),
    RegExp(r'(\d{1,3}(?:[,.]\d{3})+|\d+)\s?(?:円|JPY|yen)', caseSensitive: false),
  ];
  final found = <(int, int)>[]; // (posizione, valore)
  for (final re in patterns) {
    for (final m in re.allMatches(text)) {
      final digits = m.group(1)!.replaceAll(RegExp(r'[,.]'), '');
      final v = int.tryParse(digits);
      if (v != null && v > 0 && v < 100000000) found.add((m.start, v));
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final out = <int>[];
  for (final f in found) {
    if (!out.contains(f.$2)) out.add(f.$2);
    if (out.length >= max) break;
  }
  return out;
}

String formatEur(double v) => '€ ${_group(v.toStringAsFixed(2), ',', '.')}';
String formatYen(double v) => '¥ ${_group(v.round().toString(), null, '.')}';

String _group(String fixed, String? decimalSep, String thousandsSep) {
  final neg = fixed.startsWith('-');
  final body = neg ? fixed.substring(1) : fixed;
  final parts = body.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var k = 0; k < intPart.length; k++) {
    if (k > 0 && (intPart.length - k) % 3 == 0) buf.write(thousandsSep);
    buf.write(intPart[k]);
  }
  var out = buf.toString();
  if (parts.length > 1 && decimalSep != null) out = '$out$decimalSep${parts[1]}';
  return neg ? '-$out' : out;
}
