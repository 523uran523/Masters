
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier copyWith({
    Object? id = _unset,
    Object? name = _unset,
    Object? phone = _unset,
    Object? note = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return Supplier(
      id: id == _unset ? this.id : id as String,
      name: name == _unset ? this.name : name as String,
      phone: phone == _unset ? this.phone : phone as String,
      note: note == _unset ? this.note : note as String?,
      createdAt: createdAt == _unset ? this.createdAt : createdAt as DateTime,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Supplier.fromMap(Map<String, Object?> m) => Supplier(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String? ?? '',
        note: m['note'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int? ?? 0),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int? ?? (m['created_at'] as int? ?? 0)),
      );

  static const Object _unset = Object();
}

class Purchase {
  const Purchase({
    required this.id,
    this.supplierId,
    this.accountId,
    required this.totalCents,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? supplierId;
  final String? accountId;
  final int totalCents;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'account_id': accountId,
        'total_cents': totalCents,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Purchase.fromMap(Map<String, Object?> m) => Purchase(
        id: m['id'] as String,
        supplierId: m['supplier_id'] as String?,
        accountId: m['account_id'] as String?,
        totalCents: m['total_cents'] as int? ?? 0,
        note: m['note'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int? ?? 0),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int? ?? (m['created_at'] as int? ?? 0)),
      );
}

class PurchaseLine {
  const PurchaseLine({
    required this.id,
    required this.purchaseId,
    required this.itemId,
    required this.qty,
    this.unitPriceCents = 0,
  });

  final String id;
  final String purchaseId;
  final String itemId;
  final double qty;
  final int unitPriceCents;

  Map<String, Object?> toMap() => {
        'id': id,
        'purchase_id': purchaseId,
        'item_id': itemId,
        'qty': qty,
        'unit_price_cents': unitPriceCents,
      };

  factory PurchaseLine.fromMap(Map<String, Object?> m) => PurchaseLine(
        id: m['id'] as String,
        purchaseId: m['purchase_id'] as String,
        itemId: m['item_id'] as String,
        qty: (m['qty'] as num?)?.toDouble() ?? 0,
        unitPriceCents: m['unit_price_cents'] as int? ?? 0,
      );
}
