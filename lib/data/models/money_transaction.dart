class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.accountId,
    required this.kind,
    required this.direction,
    required this.amountCents,
    this.category = '',
    this.note,
    this.clientId,
    this.jobId,
    this.shiftId,
    this.relatedTransactionId,
    required this.createdAt,
    this.voided = false,
  });

  final String id;
  final String accountId;
  final String kind; // income, expense, sale, payment, refund, transfer, debt, adjustment, payroll
  final String direction; // in / out
  final int amountCents;
  final String category;
  final String? note;
  final String? clientId;
  final String? jobId;
  final String? shiftId;
  final String? relatedTransactionId;
  final DateTime createdAt;
  final bool voided;

  int get signedAmount => direction == 'in' ? amountCents : -amountCents;

  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'kind': kind,
        'direction': direction,
        'amount_cents': amountCents,
        'category': category,
        'note': note,
        'client_id': clientId,
        'job_id': jobId,
        'shift_id': shiftId,
        'related_transaction_id': relatedTransactionId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'voided': voided ? 1 : 0,
      };

  factory MoneyTransaction.fromMap(Map<String, Object?> m) => MoneyTransaction(
        id: m['id'] as String,
        accountId: m['account_id'] as String,
        kind: m['kind'] as String,
        direction: m['direction'] as String,
        amountCents: m['amount_cents'] as int? ?? 0,
        category: m['category'] as String? ?? '',
        note: m['note'] as String?,
        clientId: m['client_id'] as String?,
        jobId: m['job_id'] as String?,
        shiftId: m['shift_id'] as String?,
        relatedTransactionId: m['related_transaction_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int? ?? 0),
        voided: (m['voided'] as int? ?? 0) == 1,
      );
}
