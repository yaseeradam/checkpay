import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';

class PaymentScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  const PaymentScreen({super.key, required this.schoolClass});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<Student> _students = [];
  bool _loading = true;
  int _monthOffset = 0;
  final _months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students = await DB.getStudentsForMonth(
        widget.schoolClass.name, _currentMonth, _currentYear);
    if (mounted) setState(() { _students = students; _loading = false; });
  }

  String _monthLabel(int offset) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month + offset);
    return '${_months[d.month - 1]} ${d.year}';
  }

  String get _currentMonth {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month + _monthOffset);
    return _months[d.month - 1];
  }

  int get _currentYear {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _monthOffset).year;
  }

  Future<void> _togglePayment(Student s) async {
    final newVal = !s.isPaid;
    await DB.setPayment(s.id, _currentMonth, _currentYear, newVal);
    setState(() => s.isPaid = newVal);
  }

  int get _paidCount => _students.where((s) => s.isPaid).length;
  double get _collected => _paidCount * widget.schoolClass.feeAmount;

  String _fmt(double amount) {
    final s = amount.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₦${buf.toString()}';
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
                        Text('Class ${widget.schoolClass.name}', style: ts(20, FontWeight.w800, Colors.white)),
                        Text('Mark payments for this month',
                            style: ts(12, FontWeight.w500, Colors.white.withOpacity(0.75))),
                      ])),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.chevron_left_rounded, color: kSlate400),
                        onPressed: () { setState(() => _monthOffset--); _load(); }),
                    Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_monthLabel(_monthOffset - 1), style: ts(11, FontWeight.w600, const Color(0xFFD1D5DB))),
                      const SizedBox(width: 12),
                      Text(_monthLabel(_monthOffset), style: ts(14, FontWeight.w800, kSlate900)),
                      const SizedBox(width: 12),
                      Text(_monthLabel(_monthOffset + 1), style: ts(11, FontWeight.w600, const Color(0xFFD1D5DB))),
                    ])),
                    IconButton(icon: const Icon(Icons.chevron_right_rounded, color: kSlate400),
                        onPressed: () { setState(() => _monthOffset++); _load(); }),
                  ]),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                  itemCount: _students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = _students[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kSlate100,
                          backgroundImage: s.photoPath != null ? FileImage(File(s.photoPath!)) : null,
                          child: s.photoPath == null
                              ? Text(s.initials, style: ts(12, FontWeight.w700, kSlate500))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.name, style: ts(14, FontWeight.w700, kSlate900)),
                          Text('ID: #${s.id}', style: ts(10, FontWeight.w700, kSlate400, letterSpacing: 0.5)),
                        ])),
                        GestureDetector(
                          onTap: () => _togglePayment(s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: s.isPaid ? kPrimary : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: s.isPaid
                                  ? [BoxShadow(color: kPrimary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]
                                  : [],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (s.isPaid) ...[const Icon(Icons.check_rounded, color: Colors.white, size: 16), const SizedBox(width: 4)],
                              Text(s.isPaid ? 'Paid' : 'Mark Paid',
                                  style: ts(13, FontWeight.w700, s.isPaid ? Colors.white : const Color(0xFF6B7280))),
                            ]),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ]),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0), Colors.white]),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(color: kSlate900, borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Collected', style: ts(11, FontWeight.w700, kSlate400, letterSpacing: 1)),
              Text(_fmt(_collected), style: ts(20, FontWeight.w800, Colors.white)),
            ]),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), elevation: 0),
              child: Row(children: [
                Text('Finish Session', style: ts(14, FontWeight.w700, Colors.white)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
