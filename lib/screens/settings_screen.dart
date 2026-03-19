import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<SchoolClass> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final classes = await DB.getClasses();
    if (mounted) setState(() { _classes = classes; _loading = false; });
  }

  void _showEditDialog(SchoolClass c) {
    final ctrl = TextEditingController(text: c.feeAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Edit Fee – ${c.name}', style: ts(16, FontWeight.w700, kSlate900)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₦',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: ts(14, FontWeight.w600, kSlate500))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showConfirmDialog(c, double.tryParse(ctrl.text) ?? c.feeAmount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
            child: Text('Update', style: ts(14, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(SchoolClass c, double newFee) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64,
              decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.info_outline_rounded, color: kPrimary, size: 32)),
            const SizedBox(height: 20),
            Text('Confirm Fee Change', style: ts(18, FontWeight.w800, kSlate900)),
            const SizedBox(height: 12),
            Text('Update tuition fee for ${c.name} to ${_fmt(newFee)}?',
                textAlign: TextAlign.center, style: ts(13, FontWeight.w400, kSlate500, height: 1.6)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await DB.updateClassFee(c.id, newFee);
                  if (mounted) Navigator.pop(context);
                  _load();
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 2, shadowColor: kPrimary.withOpacity(0.2)),
                child: Text('Confirm Update', style: ts(15, FontWeight.w700, Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(backgroundColor: kSlate100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                child: Text('Cancel', style: ts(15, FontWeight.w700, kSlate500)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

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
      backgroundColor: kBackground,
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
                        Text('School Fees', style: ts(20, FontWeight.w800, Colors.white)),
                        Text('Manage tuition rates per class',
                            style: ts(12, FontWeight.w500, Colors.white.withOpacity(0.75))),
                      ])),
                    ]),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ..._classes.map((c) {
                  final isJunior = c.name.startsWith('JSS');
                  final accentColor = isJunior ? kPrimary : const Color(0xFF60A5FA);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
                      child: Row(children: [
                        Container(width: 48, height: 48,
                          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(isJunior ? Icons.school_outlined : Icons.history_edu_outlined, color: accentColor)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.section, style: ts(11, FontWeight.w600, kSlate400, letterSpacing: 0.5)),
                          Text(c.name, style: ts(17, FontWeight.w800, kSlate900)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(_fmt(c.feeAmount), style: ts(16, FontWeight.w800, kSlate900)),
                          GestureDetector(
                            onTap: () => _showEditDialog(c),
                            child: Row(children: [
                              const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF60A5FA)),
                              const SizedBox(width: 2),
                              Text('Edit', style: ts(12, FontWeight.w600, const Color(0xFF60A5FA))),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ]),
    );
  }
}
