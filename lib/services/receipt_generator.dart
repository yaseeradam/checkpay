import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models.dart';

class ReceiptGenerator {
  static Future<String> generatePdf({
    required Student student,
    required List<PaymentRecord> history,
    required String schoolName,
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();

    final paidRecords = history.where((r) => r.paid).toList();
    final unpaidRecords = history.where((r) => !r.paid).toList();

    final brandBlue   = PdfColor.fromHex('#335BBD');
    final brandDark   = PdfColor.fromHex('#1E3D8F');
    final textDark    = PdfColor.fromHex('#0F172A');
    final textMuted   = PdfColor.fromHex('#64748B');
    final lineColor   = PdfColor.fromHex('#E2E8F0');
    final successGreen = PdfColor.fromHex('#16A34A');
    final dangerRed   = PdfColor.fromHex('#DC2626');
    final successBg   = PdfColor.fromHex('#DCFCE7');
    final dangerBg    = PdfColor.fromHex('#FEE2E2');

    pw.ImageProvider? logoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try { logoImage = pw.MemoryImage(logoBytes); } catch (_) {}
    }

    // Receipt-width page: 80mm wide, height auto via content
    const pageFormat = PdfPageFormat(226.77, double.infinity, marginAll: 0);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // ── Header ──
            pw.Container(
              width: double.infinity,
              color: brandDark,
              padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 44, height: 44,
                      child: pw.ClipOval(child: pw.Image(logoImage, fit: pw.BoxFit.cover)),
                    ),
                    pw.SizedBox(height: 6),
                  ],
                  pw.Text(schoolName.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white, letterSpacing: 1.5)),
                  pw.SizedBox(height: 4),
                  pw.Container(width: 40, height: 1.5,
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#5B7FD4'),
                          borderRadius: pw.BorderRadius.circular(99))),
                  pw.SizedBox(height: 4),
                  pw.Text('PAYMENT RECEIPT',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#93B4FF'), letterSpacing: 2)),
                ],
              ),
            ),

            // ── Receipt No & Date ──
            pw.Container(
              width: double.infinity,
              color: PdfColor.fromHex('#F8FAFC'),
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('RECEIPT NO.', style: pw.TextStyle(fontSize: 6,
                        fontWeight: pw.FontWeight.bold, color: textMuted, letterSpacing: 1)),
                    pw.Text('#${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('DATE ISSUED', style: pw.TextStyle(fontSize: 6,
                        fontWeight: pw.FontWeight.bold, color: textMuted, letterSpacing: 1)),
                    pw.Text(DateTime.now().toString().substring(0, 10),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark)),
                  ]),
                ],
              ),
            ),

            _divider(lineColor),

            // ── Student Info ──
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sectionLabel('STUDENT INFORMATION', brandBlue),
                  pw.SizedBox(height: 6),
                  _infoRow('Name', student.name, textMuted, textDark),
                  pw.SizedBox(height: 4),
                  _infoRow('Student ID', '#${student.id}', textMuted, textDark),
                  pw.SizedBox(height: 4),
                  _infoRow('Class', student.className, textMuted, textDark),
                ],
              ),
            ),

            _divider(lineColor),

            // ── Summary ──
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sectionLabel('PAYMENT SUMMARY', brandBlue),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    _summaryChip('Total Months', '${history.length}', brandBlue, PdfColor.fromHex('#EEF2FF')),
                    pw.SizedBox(width: 6),
                    _summaryChip('Paid', '${paidRecords.length}', successGreen, successBg),
                    pw.SizedBox(width: 6),
                    _summaryChip('Unpaid', '${unpaidRecords.length}', dangerRed, dangerBg),
                  ]),
                ],
              ),
            ),

            _divider(lineColor),

            // ── Payment History Table ──
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sectionLabel('PAYMENT HISTORY', brandBlue),
                  pw.SizedBox(height: 8),
                  // Table header
                  pw.Container(
                    color: brandDark,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Row(children: [
                      pw.Expanded(flex: 1, child: pw.Text('#', style: _thStyle())),
                      pw.Expanded(flex: 4, child: pw.Text('MONTH', style: _thStyle())),
                      pw.Expanded(flex: 4, child: pw.Text('DATE PAID', style: _thStyle())),
                      pw.Expanded(flex: 3, child: pw.Text('STATUS', textAlign: pw.TextAlign.right, style: _thStyle())),
                    ]),
                  ),
                  // Table rows
                  ...List.generate(history.length, (i) {
                    final r = history[i];
                    final bg = i % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F8FAFC');
                    return pw.Container(
                      color: bg,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: pw.Row(children: [
                        pw.Expanded(flex: 1, child: pw.Text('${i + 1}',
                            style: pw.TextStyle(fontSize: 7, color: textMuted))),
                        pw.Expanded(flex: 4, child: pw.Text('${r.month} ${r.year}',
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textDark))),
                        pw.Expanded(flex: 4, child: pw.Text(r.paid ? (r.date ?? '-') : '-',
                            style: pw.TextStyle(fontSize: 7, color: textMuted))),
                        pw.Expanded(flex: 3, child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: r.paid ? successBg : dangerBg,
                            borderRadius: pw.BorderRadius.circular(99),
                          ),
                          child: pw.Text(r.paid ? 'Paid' : 'Unpaid',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold,
                                color: r.paid ? successGreen : dangerRed)),
                        )),
                      ]),
                    );
                  }),
                  // Table bottom border
                  pw.Container(height: 1, color: lineColor),
                ],
              ),
            ),

            _divider(lineColor),

            // ── Footer ──
            pw.Container(
              width: double.infinity,
              color: PdfColor.fromHex('#F8FAFC'),
              padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Thank you!',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: brandBlue)),
                  pw.SizedBox(height: 4),
                  pw.Text('This is a computer-generated receipt.',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 7, color: textMuted)),
                  pw.Text('Generated by CheckPay · ${DateTime.now().toString().substring(0, 16)}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 6, color: PdfColor.fromHex('#94A3B8'))),
                  pw.SizedBox(height: 6),
                  // Barcode-like decoration
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: List.generate(28, (i) => pw.Container(
                      width: i % 3 == 0 ? 3 : 1.5,
                      height: 18,
                      margin: const pw.EdgeInsets.symmetric(horizontal: 0.5),
                      color: i % 5 == 0 ? PdfColor.fromHex('#CBD5E1') : PdfColor.fromHex('#0F172A'),
                    )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'CheckPay_Receipt_${student.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  // ── PDF helpers ──
  static pw.Widget _divider(PdfColor color) =>
      pw.Container(height: 1, color: color, margin: const pw.EdgeInsets.symmetric(horizontal: 12));

  static pw.Widget _sectionLabel(String text, PdfColor color) =>
      pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold,
          color: color, letterSpacing: 1.5));

  static pw.Widget _infoRow(String label, String value, PdfColor labelColor, PdfColor valueColor) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: labelColor)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: valueColor)),
      ]);

  static pw.Widget _summaryChip(String label, String value, PdfColor color, PdfColor bg) =>
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: 0.5)),
        ]),
      ));

  static pw.TextStyle _thStyle() => pw.TextStyle(
      fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5);

  // ── Image receipt ──
  static Future<String> generateImage({
    required Student student,
    required List<PaymentRecord> history,
    required String schoolName,
    Uint8List? logoBytes,
  }) async {
    const double w = 560;
    final double rowsH = history.length * 36.0;
    final double h = 520 + rowsH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    _paintReceipt(canvas, Size(w, h), student, history, schoolName);

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'CheckPay_Receipt_${student.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  static void _paintReceipt(Canvas canvas, Size size, Student student,
      List<PaymentRecord> history, String schoolName) {
    final w = size.width;
    double y = 0;

    // White background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = Colors.white);

    // ── Header ──
    final headerH = 110.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, headerH),
        Paint()..color = const Color(0xFF1E3D8F));
    _text(canvas, schoolName.toUpperCase(), Offset(w / 2, 28),
        fontSize: 16, color: Colors.white, weight: FontWeight.w800,
        align: TextAlign.center, maxW: w - 40, spacing: 2);
    // divider line
    canvas.drawLine(Offset(w / 2 - 30, 52), Offset(w / 2 + 30, 52),
        Paint()..color = const Color(0xFF5B7FD4)..strokeWidth = 2..strokeCap = StrokeCap.round);
    _text(canvas, 'PAYMENT RECEIPT', Offset(w / 2, 62),
        fontSize: 10, color: const Color(0xFF93B4FF), weight: FontWeight.w700,
        align: TextAlign.center, maxW: w - 40, spacing: 3);
    _text(canvas, 'Generated: ${DateTime.now().toString().substring(0, 10)}',
        Offset(w / 2, 84),
        fontSize: 9, color: Colors.white.withOpacity(0.6),
        align: TextAlign.center, maxW: w - 40);
    y = headerH;

    // ── Receipt No & Date row ──
    canvas.drawRect(Rect.fromLTWH(0, y, w, 36),
        Paint()..color = const Color(0xFFF8FAFC));
    _text(canvas, 'RECEIPT NO.', Offset(16, y + 6),
        fontSize: 7, color: const Color(0xFF64748B), weight: FontWeight.w700, spacing: 1);
    _text(canvas, '#${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        Offset(16, y + 18), fontSize: 10, color: const Color(0xFF0F172A), weight: FontWeight.w800);
    _text(canvas, 'DATE ISSUED', Offset(w - 16, y + 6),
        fontSize: 7, color: const Color(0xFF64748B), weight: FontWeight.w700,
        align: TextAlign.right, maxW: 160, spacing: 1);
    _text(canvas, DateTime.now().toString().substring(0, 10), Offset(w - 16, y + 18),
        fontSize: 10, color: const Color(0xFF0F172A), weight: FontWeight.w800,
        align: TextAlign.right, maxW: 160);
    y += 36;

    _hLine(canvas, y, w); y += 1;

    // ── Student Info ──
    y += 12;
    _text(canvas, 'STUDENT INFORMATION', Offset(16, y),
        fontSize: 8, color: const Color(0xFF335BBD), weight: FontWeight.w700, spacing: 1.5);
    y += 16;
    _labelValue(canvas, 'Name', student.name, y, w); y += 22;
    _labelValue(canvas, 'Student ID', '#${student.id}', y, w); y += 22;
    _labelValue(canvas, 'Class', student.className, y, w); y += 14;

    _hLine(canvas, y, w); y += 1;

    // ── Summary ──
    y += 12;
    _text(canvas, 'PAYMENT SUMMARY', Offset(16, y),
        fontSize: 8, color: const Color(0xFF335BBD), weight: FontWeight.w700, spacing: 1.5);
    y += 14;
    final paidCount = history.where((r) => r.paid).length;
    final unpaidCount = history.where((r) => !r.paid).length;
    final chipW = (w - 48) / 3;
    _chip(canvas, Rect.fromLTWH(16, y, chipW, 52),
        'TOTAL', '${history.length}', const Color(0xFF335BBD), const Color(0xFFEEF2FF));
    _chip(canvas, Rect.fromLTWH(16 + chipW + 8, y, chipW, 52),
        'PAID', '$paidCount', const Color(0xFF16A34A), const Color(0xFFDCFCE7));
    _chip(canvas, Rect.fromLTWH(16 + (chipW + 8) * 2, y, chipW, 52),
        'UNPAID', '$unpaidCount', const Color(0xFFDC2626), const Color(0xFFFEE2E2));
    y += 64;

    _hLine(canvas, y, w); y += 1;

    // ── Payment History ──
    y += 12;
    _text(canvas, 'PAYMENT HISTORY', Offset(16, y),
        fontSize: 8, color: const Color(0xFF335BBD), weight: FontWeight.w700, spacing: 1.5);
    y += 14;

    // Table header
    canvas.drawRect(Rect.fromLTWH(16, y, w - 32, 28),
        Paint()..color = const Color(0xFF1E3D8F));
    _text(canvas, '#', Offset(24, y + 8), fontSize: 8, color: Colors.white, weight: FontWeight.w700);
    _text(canvas, 'MONTH', Offset(52, y + 8), fontSize: 8, color: Colors.white, weight: FontWeight.w700);
    _text(canvas, 'DATE PAID', Offset(w * 0.52, y + 8), fontSize: 8, color: Colors.white, weight: FontWeight.w700);
    _text(canvas, 'STATUS', Offset(w - 24, y + 8),
        fontSize: 8, color: Colors.white, weight: FontWeight.w700, align: TextAlign.right, maxW: 80);
    y += 28;

    for (int i = 0; i < history.length; i++) {
      final r = history[i];
      final rowBg = i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);
      canvas.drawRect(Rect.fromLTWH(16, y, w - 32, 32), Paint()..color = rowBg);

      _text(canvas, '${i + 1}', Offset(24, y + 10),
          fontSize: 9, color: const Color(0xFF64748B));
      _text(canvas, '${r.month} ${r.year}', Offset(52, y + 10),
          fontSize: 9, color: const Color(0xFF0F172A), weight: FontWeight.w700);
      _text(canvas, r.paid ? (r.date ?? '-') : '-', Offset(w * 0.52, y + 10),
          fontSize: 9, color: const Color(0xFF64748B));

      // Status badge
      final badgeColor = r.paid ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      final badgeBg = r.paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
      final badgeW = 56.0;
      final badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w - 24 - badgeW, y + 7, badgeW, 18), const Radius.circular(99));
      canvas.drawRRect(badgeRect, Paint()..color = badgeBg);
      _text(canvas, r.paid ? 'Paid' : 'Unpaid',
          Offset(w - 24 - badgeW / 2, y + 10),
          fontSize: 8, color: badgeColor, weight: FontWeight.w700,
          align: TextAlign.center, maxW: badgeW);
      y += 32;
    }

    // Table border
    canvas.drawRect(Rect.fromLTWH(16, y - history.length * 32 - 28, w - 32, history.length * 32 + 28),
        Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.stroke..strokeWidth = 1);

    _hLine(canvas, y, w); y += 1;

    // ── Footer ──
    canvas.drawRect(Rect.fromLTWH(0, y, w, size.height - y),
        Paint()..color = const Color(0xFFF8FAFC));
    y += 16;
    _text(canvas, 'Thank you!', Offset(w / 2, y),
        fontSize: 13, color: const Color(0xFF335BBD), weight: FontWeight.w800,
        align: TextAlign.center, maxW: w - 40);
    y += 20;
    _text(canvas, 'This is a computer-generated receipt from CheckPay.',
        Offset(w / 2, y), fontSize: 9, color: const Color(0xFF64748B),
        align: TextAlign.center, maxW: w - 40);
    y += 16;
    _text(canvas, 'Generated on ${DateTime.now().toString().substring(0, 16)}',
        Offset(w / 2, y), fontSize: 8, color: const Color(0xFF94A3B8),
        align: TextAlign.center, maxW: w - 40);
    y += 20;

    // Barcode decoration
    final barPaint = Paint()..strokeCap = StrokeCap.butt;
    double bx = w / 2 - 80;
    for (int i = 0; i < 40; i++) {
      final bw = i % 3 == 0 ? 4.0 : 2.0;
      barPaint.color = i % 5 == 0 ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A);
      canvas.drawRect(Rect.fromLTWH(bx, y, bw, 22), barPaint);
      bx += bw + 1.5;
    }
  }

  static void _hLine(Canvas canvas, double y, double w) =>
      canvas.drawLine(Offset(0, y), Offset(w, y),
          Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1);

  static void _labelValue(Canvas canvas, String label, String value, double y, double w) {
    _text(canvas, label, Offset(16, y), fontSize: 10, color: const Color(0xFF64748B));
    _text(canvas, value, Offset(w - 16, y),
        fontSize: 10, color: const Color(0xFF0F172A), weight: FontWeight.w700,
        align: TextAlign.right, maxW: w * 0.6);
  }

  static void _chip(Canvas canvas, Rect rect, String label, String value,
      Color color, Color bg) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = bg);
    canvas.drawRRect(rr, Paint()..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 1);
    _text(canvas, value, Offset(rect.center.dx, rect.top + 10),
        fontSize: 20, color: color, weight: FontWeight.w900,
        align: TextAlign.center, maxW: rect.width - 8);
    _text(canvas, label, Offset(rect.center.dx, rect.top + 34),
        fontSize: 7, color: color, weight: FontWeight.w700,
        align: TextAlign.center, maxW: rect.width - 8, spacing: 0.5);
  }

  static void _text(Canvas canvas, String text, Offset pos, {
    double fontSize = 12,
    Color color = Colors.black,
    FontWeight weight = FontWeight.normal,
    TextAlign align = TextAlign.left,
    double maxW = 400,
    double spacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          fontSize: fontSize, color: color, fontWeight: weight, letterSpacing: spacing)),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxW);

    final dx = align == TextAlign.center
        ? pos.dx - tp.width / 2
        : align == TextAlign.right
            ? pos.dx - tp.width
            : pos.dx;
    tp.paint(canvas, Offset(dx, pos.dy));
  }
}
