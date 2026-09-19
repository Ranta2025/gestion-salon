import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/date_helpers.dart';
import '../core/utils/formatters.dart';
import '../core/utils/labels.dart';
import '../data/models/models.dart';

/// CSV + PDF generation. Everything is built in-memory and shared through
/// the OS sheet — export works in airplane mode.
class ExportService {
  String _csvCell(String? value) {
    final v = value ?? '';
    return '"${v.replaceAll('"', '""')}"';
  }

  Future<String> shareCsv({
    required List<Movement> movements,
    required String periodLabel,
  }) async {
    final buffer = StringBuffer()
      ..writeln(
        'Fecha,Tipo,Categoría,Cliente,Empleado,Proveedor,Método de pago,Monto,Nota',
      );
    for (final m in movements) {
      buffer.writeln(
        [
          _csvCell(DateHelpers.dateTimeKey(m.date)),
          _csvCell(m.type.labelEs),
          _csvCell(m.categoryName),
          _csvCell(m.clientName),
          _csvCell(m.employee),
          _csvCell(m.supplier),
          _csvCell(Labels.payment(m.paymentMethod)),
          m.amount.toStringAsFixed(2),
          _csvCell(m.note),
        ].join(','),
      );
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/reporte_$stamp.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Reporte $periodLabel'),
    );
    return file.path;
  }

  Future<Uint8List> buildPdf({
    required String periodLabel,
    required Totals totals,
    required List<Movement> movements,
    Uint8List? piePng,
    Uint8List? trendPng,
  }) async {
    final doc = pw.Document();

    final headerStyle = pw.TextStyle(
      fontSize: 22,
      fontWeight: pw.FontWeight.bold,
    );

    pw.Widget totalRow(String label, num value, PdfColor color) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
            pw.Text(
              Formatters.money(value),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('Gestión Salón', style: headerStyle),
          pw.SizedBox(height: 4),
          pw.Text('Reporte · $periodLabel'),
          pw.Text('Generado: ${DateHelpers.humanDate(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                totalRow('Ingresos', totals.income, PdfColors.green800),
                pw.SizedBox(height: 4),
                totalRow('Gastos', totals.expense, PdfColors.red800),
                pw.Divider(),
                totalRow(
                  'Balance neto',
                  totals.net,
                  totals.net >= 0 ? PdfColors.green800 : PdfColors.red800,
                ),
              ],
            ),
          ),
          if (piePng != null || trendPng != null) pw.SizedBox(height: 16),
          if (piePng != null)
            pw.Center(
              child: pw.Image(pw.MemoryImage(piePng), height: 200),
            ),
          if (trendPng != null) ...[
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Image(pw.MemoryImage(trendPng), height: 160),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Movimientos (${movements.length})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
            headers: const ['Fecha', 'Tipo', 'Detalle', 'Monto'],
            data: movements
                .map(
                  (m) => [
                    '${DateHelpers.humanShort(m.date)} '
                        '${DateHelpers.humanTime(m.date)}',
                    m.type.labelEs,
                    [
                      m.categoryName ?? '-',
                      if (m.clientName != null) m.clientName!,
                      if (m.note != null && m.note!.isNotEmpty) m.note!,
                    ].join(' · '),
                    Formatters.money(m.amount),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> sharePdf({
    required String periodLabel,
    required Totals totals,
    required List<Movement> movements,
    Uint8List? piePng,
    Uint8List? trendPng,
  }) async {
    final bytes = await buildPdf(
      periodLabel: periodLabel,
      totals: totals,
      movements: movements,
      piePng: piePng,
      trendPng: trendPng,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'reporte_gestion_salon.pdf',
    );
  }
}
