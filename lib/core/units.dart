/// Единицы измерения, общие для склада, состава стоимости и калькулятора.
///
/// Все значения хранятся как строки, чтобы пользователь мог задать свою
/// единицу («упак», «услуга» и т.п.). Для известных единиц работает перевод
/// внутри одной «семьи» (масса, объём, длина, площадь).
library;

const List<String> kUnitOptions = [
  'шт',
  'г',
  'кг',
  'мл',
  'л',
  'см',
  'м',
  'м²',
  'упак',
  'услуга',
];

/// Единицы, в которых можно указать количество в калькуляторе.
const List<String> kQtyUnits = ['шт', 'г', 'кг', 'мл', 'л', 'см', 'м', 'м²'];

/// Единицы цены («цена за ...»).
const List<String> kPriceUnits = [
  'за шт',
  'за г',
  'за 100 г',
  'за кг',
  'за мл',
  'за л',
  'за м',
  'за см',
  'за м²',
  'за упак',
  'за услугу',
];

enum UnitFamily { count, mass, volume, length, area, other }

UnitFamily unitFamily(String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'шт':
    case 'упак':
    case 'услуга':
      return UnitFamily.count;
    case 'г':
    case 'кг':
      return UnitFamily.mass;
    case 'мл':
    case 'л':
      return UnitFamily.volume;
    case 'см':
    case 'м':
      return UnitFamily.length;
    case 'м²':
    case 'м2':
      return UnitFamily.area;
    default:
      return UnitFamily.other;
  }
}

const Map<String, double> _toBase = {
  'шт': 1,
  'упак': 1,
  'услуга': 1,
  'г': 0.001,
  'кг': 1,
  'мл': 0.001,
  'л': 1,
  'см': 0.01,
  'м': 1,
  'м²': 1,
  'м2': 1,
};

/// Базовая мера единицы (кг, л, м, м², шт) — для расчёта стоимости строки.
double qtyBaseOf(String unit) => _toBase[unit] ?? 1;

/// Единица цены «за ...» → базовая мера (например, «за 100 г» → 0.1 кг).
double priceBaseOf(String priceUnit) {
  switch (priceUnit) {
    case 'за шт':
    case 'за упак':
    case 'за услугу':
    case 'за кг':
    case 'за л':
    case 'за м':
    case 'за м²':
      return 1;
    case 'за г':
      return 0.001;
    case 'за 100 г':
      return 0.1;
    case 'за мл':
      return 0.001;
    case 'за см':
      return 0.01;
    default:
      return 1;
  }
}

bool unitsCompatible(String a, String b) {
  final family = unitFamily(a);
  return family != UnitFamily.other && family == unitFamily(b);
}

/// Переводит [value] из единицы [from] в [to].
/// Возвращает `null`, если единицы несовместимы.
double? convertQty(double value, String from, String to) {
  if (from == to) return value;
  if (!unitsCompatible(from, to)) return null;
  final source = _toBase[from];
  final target = _toBase[to];
  if (source == null || target == null || target == 0) return null;
  return value * source / target;
}

/// Единица цены по умолчанию для единицы количества.
String defaultPriceUnit(String qtyUnit) {
  switch (qtyUnit) {
    case 'г':
      return 'за г';
    case 'кг':
      return 'за кг';
    case 'мл':
      return 'за мл';
    case 'л':
      return 'за л';
    case 'см':
      return 'за см';
    case 'м':
      return 'за м';
    case 'м²':
      return 'за м²';
    case 'упак':
      return 'за упак';
    case 'услуга':
      return 'за услугу';
    default:
      return 'за шт';
  }
}

/// Доступные единицы цены для единицы количества.
List<String> priceUnitsFor(String qtyUnit) {
  switch (unitFamily(qtyUnit)) {
    case UnitFamily.mass:
      return const ['за г', 'за 100 г', 'за кг'];
    case UnitFamily.volume:
      return const ['за мл', 'за л'];
    case UnitFamily.length:
      return const ['за см', 'за м'];
    case UnitFamily.area:
      return const ['за м²'];
    case UnitFamily.count:
      return qtyUnit == 'упак'
          ? const ['за упак']
          : (qtyUnit == 'услуга'
                ? const ['за услугу']
                : const ['за шт']);
    case UnitFamily.other:
      return kPriceUnits;
  }
}

/// Компактная запись количества: без лишних нулей.
String formatQty(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  if (value % 1 == 0) return value.toInt().toString();
  final fixed = value.toStringAsFixed(3);
  return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
