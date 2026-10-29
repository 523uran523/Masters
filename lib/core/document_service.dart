import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'utils/app_utils.dart';
import '../data/models/job.dart';
import '../state/masters_store.dart';

class DocumentService {
  static Future<Uint8List> buildJobPdf({
    required MastersStore store,
    required Job job,
    required String type,
  }) async {
    final pdf = pw.Document();
    final client = store.clientById(job.clientId);
    final obj = store.objectById(job.objectId);
    final materials = store.materialsForJob(job.id);
    final sessionsMinutes = store.totalMinutesForJob(job.id);
    final paid = store.paidForJob(job.id);
    final created = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(type, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('№ ${job.id}  от ${DateFormat('dd.MM.yyyy', 'ru').format(created)}', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 12),
              pw.Text('Клиент: ${client?.name ?? '—'}', style: const pw.TextStyle(fontSize: 12)),
              if (client != null && client.phone.isNotEmpty)
                pw.Text('Телефон: ${client.phone}', style: const pw.TextStyle(fontSize: 12)),
              if (obj != null) pw.Text('Объект: ${obj.title}', style: const pw.TextStyle(fontSize: 12)),
              if (job.note != null) pw.Text('Заметка: ${job.note!}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              pw.Text('Заказ: ${job.title}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              if (materials.isNotEmpty) ...[
                pw.Text('Материалы', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.TableHelper.fromTextArray(
                  headers: ['Наименование', 'Кол-во', 'Ед.', 'Цена', 'Сумма'],
                  data: [
                    for (final m in materials)
                      [
                        m.name,
                        m.quantity.toStringAsFixed(m.quantity % 1 == 0 ? 0 : 2),
                        m.unit,
                        (m.priceCents / 100).toStringAsFixed(2),
                        (m.totalCents / 100).toStringAsFixed(2),
                      ],
                  ],
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
              ],
              pw.Text('Время работ: ${formatMinutes(sessionsMinutes)}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Итого к оплате', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Text('${(job.priceCents / 100).toStringAsFixed(2)} ₽', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Уже оплачено')),
                pw.Text('${(paid / 100).toStringAsFixed(2)} ₽'),
              ]),
              pw.Row(children: [
                pw.Expanded(child: pw.Text('Остаток')),
                pw.Text('${((job.priceCents - paid) / 100).toStringAsFixed(2)} ₽'),
              ]),
              pw.SizedBox(height: 16),
              pw.Text('Спасибо за обращение!', style: const pw.TextStyle(fontSize: 11)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> buildPayrollPdf({
    required String title,
    required List<Map<String, Object?>> summary,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: const ['Сотрудник', 'Зарплата', 'Бонусы', 'Штрафы', 'Аванс', 'Выплата', 'К выплате'],
                data: [
                  for (final row in summary)
                    [
                      (row['employeeName'] ?? row['employee']?.toString() ?? '?').toString(),
                      (row['earned'] as int? ?? 0).toString(),
                      (row['bonus'] as int? ?? 0).toString(),
                      (row['penalty'] as int? ?? 0).toString(),
                      (row['advance'] as int? ?? 0).toString(),
                      (row['payout'] as int? ?? 0).toString(),
                      (row['net'] as int? ?? 0).toString(),
                    ],
                ],
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<bool> savePdf(Uint8List bytes, String suggestedName) async {
    final uri = await FilePicker.saveFile(
      fileName: suggestedName,
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Сохранить документ',
    );
    return uri != null;
  }
}