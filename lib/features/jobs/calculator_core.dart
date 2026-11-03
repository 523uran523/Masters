import '../../core/units.dart';

/// Итоги калькулятора: материалы + работа + прочие расходы,
/// накладные процентом от базы, маржа процентом от себестоимости.
class CalculatorTotals {
  const CalculatorTotals({
    required this.materialsCents,
    required this.laborCents,
    required this.otherCents,
    required this.overheadCents,
    required this.costCents,
    required this.priceCents,
  });

  final int materialsCents;
  final int laborCents;
  final int otherCents;
  final int overheadCents;
  final int costCents;
  final int priceCents;

  int get baseCents => materialsCents + laborCents + otherCents;

  int get marginCents => priceCents - costCents;
}

/// Стоимость строки ресурса: количество в своей единице × цена за свою
/// единицу, приведённые к общей базовой мере.
int resourceLineTotalCents({
  required double qty,
  required String qtyUnit,
  required int priceCents,
  required String priceUnit,
}) {
  if (qty <= 0 || priceCents == 0) return 0;
  final priceBase = priceBaseOf(priceUnit);
  if (priceBase <= 0) return 0;
  final total = qty * qtyBaseOf(qtyUnit) / priceBase * priceCents;
  if (!total.isFinite) return 0;
  return total.round();
}

CalculatorTotals computeCalculatorTotals({
  required int materialsCents,
  required double laborHours,
  required int laborRateCents,
  required int otherCents,
  required double overheadPercent,
  required double marginPercent,
}) {
  final hours = laborHours.isFinite && laborHours > 0 ? laborHours : 0.0;
  final rate = laborRateCents < 0 ? 0 : laborRateCents;
  final labor = (hours * rate).round();
  final other = otherCents < 0 ? 0 : otherCents;
  final base = materialsCents + labor + other;
  final overheadPct = overheadPercent.isFinite && overheadPercent > 0
      ? overheadPercent
      : 0.0;
  final overhead = (base * overheadPct / 100).round();
  final cost = base + overhead;
  final marginPct = marginPercent.isFinite ? marginPercent : 0.0;
  final raw = (cost * (1 + marginPct / 100)).round();
  return CalculatorTotals(
    materialsCents: materialsCents,
    laborCents: labor,
    otherCents: other,
    overheadCents: overhead,
    costCents: cost,
    priceCents: raw < 0 ? 0 : raw,
  );
}
