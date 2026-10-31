// receiptPath stores a device-local file path; only the string is exchanged in
// backups, the file itself is not synced across devices.
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
    this.reversesId,
    required this.createdAt,
    this.voided = false,
    this.receiptPath,
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
  final String? reversesId; // id исходной операции, если это операция-возврат
  final DateTime createdAt;
  final bool voided;
  final String? receiptPath;

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
    'reverses_id': reversesId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'voided': voided ? 1 : 0,
    'receipt_path': receiptPath,
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
    reversesId: m['reverses_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      m['created_at'] as int? ?? 0,
    ),
    voided: (m['voided'] as int? ?? 0) == 1,
    receiptPath: m['receipt_path'] as String?,
  );
}
