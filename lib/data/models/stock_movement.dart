class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.qty,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String type; // in, out, writeoff, adjust
  final double qty;
  final String? note;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'item_id': itemId,
        'type': type,
        'qty': qty,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory StockMovement.fromMap(Map<String, Object?> m) => StockMovement(
        id: m['id'] as String,
        itemId: m['item_id'] as String,
        type: m['type'] as String,
        qty: (m['qty'] as num?)?.toDouble() ?? 0,
        note: m['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int? ?? 0),
      );
}