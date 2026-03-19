import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';
import '../services/app_prefs.dart';
import '../services/receipt_generator.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final Student student;
  const PaymentHistoryScreen({super.key, required this.student});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<PaymentRecord> _history = [];
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await DB.getPaymentHistory(widget.student.id);
    if (mounted) setState(() { _history = history; _loading = false; });
  }

  int get _paidCount => _history.where((r) => r.paid).length;
  int get _unpaidCount => _history.where((r) => !r.paid).length;

  // ── Format chooser (for all months) ──────────────────────
  void _showFormatChooser() {
    _showFormatChooserFor(
      records: _history,
      title: 'Download Full Receipt',
      subtitle: 'All ${_history.length} months included',
    );
  }

  // ── Format chooser (for a single month) ──────────────────
  void _showSingleMonthChooser(PaymentRecord record) {
    _showFormatChooserFor(
      records: [record],
      title: '${record.month} ${record.year}',
      subtitle: record.paid ? 'Generate receipt for this month' : 'Generate record for this month',
    );
  }

  // ── Shared format chooser bottom sheet ───────────────────
  void _showFormatChooserFor({
    required List<PaymentRecord> records,
    required String title,
    required String subtitle,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 20),
            // Title
            Text(title, style: ts(22, FontWeight.w800, kSlate900)),
            const SizedBox(height: 6),
            Text(subtitle, style: ts(14, FontWeight.w500, kSlate400)),
            const SizedBox(height: 8),
            Text('Choose your preferred format', style: ts(13, FontWeight.w500, kSlate400)),
            const SizedBox(height: 24),
            // Format options
            Row(children: [
              Expanded(child: _FormatOption(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                description: 'Best for printing',
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEE2E2),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadReceipt('pdf', records);
                },
              )),
              const SizedBox(width: 16),
              Expanded(child: _FormatOption(
                icon: Icons.image_rounded,
                label: 'Image',
                description: 'Best for sharing',
                color: const Color(0xFF335BBD),
                bgColor: const Color(0xFFEEF2FF),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadReceipt('image', records);
                },
              )),
            ]),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  // ── Download receipt ──────────────────────────────────────
  Future<void> _downloadReceipt(String format, List<PaymentRecord> records) async {
    setState(() => _downloading = true);
    try {
      // Get school info
      final schoolName = await AppPrefs.getSchoolName();
      final logoPath = await AppPrefs.getLogoPath();

      Uint8List? logoBytes;
      if (logoPath != null) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          logoBytes = await logoFile.readAsBytes();
        }
      }

      // Determine label for single vs all months
      final isSingle = records.length == 1;
      final receiptTitle = isSingle
          ? '${records.first.month} ${records.first.year} Receipt'
          : 'Full Payment Receipt';

      String filePath;
      if (format == 'pdf') {
        filePath = await ReceiptGenerator.generatePdf(
          student: widget.student,
          history: records,
          schoolName: schoolName,
          logoBytes: logoBytes,
        );
      } else {
        filePath = await ReceiptGenerator.generateImage(
          student: widget.student,
          history: records,
          schoolName: schoolName,
          logoBytes: logoBytes,
        );
      }

      if (mounted) {
        setState(() => _downloading = false);
        _showSuccessSheet(filePath, format, receiptTitle);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save receipt: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showSuccessSheet(String filePath, String format, String receiptTitle) {
    final formatLabel = format == 'pdf' ? 'PDF' : 'Image';
    final formatIcon = format == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded;
    final mimeType = format == 'pdf' ? 'application/pdf' : 'image/png';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 24),
            // Success icon with animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.3),
                      blurRadius: 20, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            Text('Receipt Ready!', style: ts(22, FontWeight.w800, kSlate900)),
            const SizedBox(height: 8),
            // Receipt title badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kSlate100, borderRadius: BorderRadius.circular(99),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(formatIcon, size: 16, color: kPrimary),
                const SizedBox(width: 6),
                Text('$receiptTitle · $formatLabel', style: ts(12, FontWeight.w700, kPrimary)),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Your receipt has been generated successfully.\nShare or save it to your device.',
                style: ts(13, FontWeight.w500, kSlate400, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            // Share button
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Share.shareXFiles(
                    [XFile(filePath, mimeType: mimeType)],
                    text: '$receiptTitle for ${widget.student.name}',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 2, shadowColor: kPrimary.withOpacity(0.3),
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: Text('Share / Save Receipt', style: ts(15, FontWeight.w700, Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            // Done button
            SizedBox(width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: kSlate100,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text('Done', style: ts(15, FontWeight.w700, kSlate500)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryDark, kPrimary, kPrimaryLight],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.student.name, style: ts(20, FontWeight.w800, Colors.white)),
                        Text('ID: #${widget.student.id} · ${widget.student.className}',
                            style: ts(12, FontWeight.w500, Colors.white.withOpacity(0.75))),
                      ])),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: kPrimary.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('STATUS', style: ts(10, FontWeight.w700, kPrimary, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(_unpaidCount > 0 ? 'Partially Paid' : _history.isEmpty ? 'No Records' : 'Fully Paid',
                              style: ts(16, FontWeight.w700, kSlate900)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('PAID / TOTAL', style: ts(10, FontWeight.w700, kPrimary, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text('$_paidCount / ${_history.length}', style: ts(16, FontWeight.w700, kSlate900)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MONTHLY HISTORY', style: ts(11, FontWeight.w700, kSlate400, letterSpacing: 1.5)),
                        if (_history.isNotEmpty)
                          Text('Tap a month for its receipt', style: ts(10, FontWeight.w500, kPrimary)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_history.isEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text('No payment records yet', style: ts(14, FontWeight.w500, kSlate400)),
                      ))
                    else
                      ...List.generate(_history.length, (i) => _TimelineItem(
                        record: _history[i],
                        isLast: i == _history.length - 1,
                        onTap: () => _showSingleMonthChooser(_history[i]),
                      )),
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                decoration: const BoxDecoration(color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
                child: ElevatedButton.icon(
                  onPressed: _downloading ? null : _showFormatChooser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary, foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 2, shadowColor: kPrimary.withOpacity(0.2),
                    disabledBackgroundColor: kPrimary.withOpacity(0.6),
                  ),
                  icon: _downloading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                  label: Text(_downloading ? 'Generating Receipt...' : 'Download Full Receipt',
                      style: ts(15, FontWeight.w700, Colors.white)),
                ),
              ),
            ]),
    );
  }
}

// ── Format Option Card ──────────────────────────────────────
class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _FormatOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 14),
          Text(label, style: ts(18, FontWeight.w800, color)),
          const SizedBox(height: 4),
          Text(description, style: ts(11, FontWeight.w500, kSlate400),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Timeline Item ───────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final PaymentRecord record;
  final bool isLast;
  final VoidCallback onTap;
  const _TimelineItem({required this.record, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: record.paid ? kPrimary : kSlate100, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
                ),
                child: record.paid
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : Center(child: Container(width: 10, height: 10,
                        decoration: const BoxDecoration(color: kSlate400, shape: BoxShape.circle))),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFF3F4F6))),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 28, top: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${record.month} ${record.year}',
                        style: ts(15, FontWeight.w700, record.paid ? kSlate900 : kSlate500)),
                    const SizedBox(height: 2),
                    Text(
                      record.paid ? 'Paid on: ${record.date}' : 'Due: ${record.month.substring(0, 3)} 05, ${record.year}',
                      style: ts(12, FontWeight.w400, kSlate400),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.receipt_long_rounded, size: 12, color: kPrimary.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text('Tap for receipt', style: ts(10, FontWeight.w500, kPrimary.withOpacity(0.5))),
                    ]),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: record.paid ? kPrimary.withOpacity(0.1) : kSlate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(record.paid ? '✓ Paid' : '☐ Unpaid',
                      style: ts(11, FontWeight.w700, record.paid ? kPrimary : kSlate400)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
