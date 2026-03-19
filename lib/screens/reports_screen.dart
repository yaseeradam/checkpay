import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<SchoolClass> _classes = [];
  List<_RecentPayment> _recentPayments = [];
  bool _loading = true;

  // Computed stats
  int _totalStudents = 0;
  int _totalPaid = 0;
  double _totalRevenue = 0;
  double _totalOutstanding = 0;

  // Monthly bar data (last 6 months paid counts)
  List<_MonthStat> _monthStats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final classes = await DB.getClasses();

    int totalStudents = 0, totalPaid = 0;
    double revenue = 0, outstanding = 0;
    final recentPayments = <_RecentPayment>[];

    for (final c in classes) {
      totalStudents += c.studentCount;
      final paid = (c.paymentProgress * c.studentCount).round();
      final unpaid = c.studentCount - paid;
      totalPaid += paid;
      revenue += paid * c.feeAmount;
      outstanding += unpaid * c.feeAmount;

      // Collect recent paid students for this class
      final students = await DB.getStudents(c.name);
      for (final s in students) {
        if (s.isPaid) {
          recentPayments.add(_RecentPayment(
            name: s.name,
            className: c.name,
            amount: c.feeAmount,
            date: 'This month',
          ));
        }
      }
    }

    // Build last 6 months stats — single DB query instead of nested loops
    final now = DateTime.now();
    final monthStats = <_MonthStat>[];
    const shortNames = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    const longNames = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];

    // Collect the 6 month names for the query
    final queryMonths = <String>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      queryMonths.add(longNames[d.month - 1]);
    }

    final paidCounts = await DB.getMonthlyPaidCounts(queryMonths, now.year);

    int allStudents = 0;
    for (final c in classes) allStudents += c.studentCount;

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      final mName = longNames[d.month - 1];
      final mPaid = paidCounts[mName] ?? 0;
      monthStats.add(_MonthStat(
        label: shortNames[d.month - 1],
        value: allStudents == 0 ? 0.0 : mPaid / allStudents,
        isCurrentMonth: i == 0,
      ));
    }

    // Sort recent payments, cap at 5
    recentPayments.sort((a, b) => b.amount.compareTo(a.amount));

    if (mounted) setState(() {
      _classes = classes;
      _totalStudents = totalStudents;
      _totalPaid = totalPaid;
      _totalRevenue = revenue;
      _totalOutstanding = outstanding;
      _recentPayments = recentPayments.take(5).toList();
      _monthStats = monthStats;
      _loading = false;
    });
  }

  double get _collectionRate => _totalStudents == 0 ? 0 : _totalPaid / _totalStudents;

  String _fmt(double amount) {
    if (amount >= 1000000) return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '₦${(amount / 1000).toStringAsFixed(0)}K';
    return '₦${amount.toStringAsFixed(0)}';
  }

  String _fmtFull(double amount) {
    final s = amount.toStringAsFixed(0);
    final buf = StringBuffer('₦');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(children: [
        // Header always visible
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Reports', style: ts(22, FontWeight.w800, Colors.white)),
                  Text('Payment analytics & overview',
                      style: ts(12, FontWeight.w500, Colors.white.withOpacity(0.75))),
                ])),
                GestureDetector(
                  onTap: () { setState(() => _loading = true); _load(); },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15), shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary)))
        else
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Summary stat cards ──────────────────────
                  _SectionTitle('Overview'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatCard(
                      icon: Icons.payments_rounded,
                      iconColor: kPrimary,
                      label: 'Total Revenue',
                      value: _fmt(_totalRevenue),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFFEF4444),
                      label: 'Outstanding',
                      value: _fmt(_totalOutstanding),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatCard(
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Total Students',
                      value: '$_totalStudents',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _StatCard(
                      icon: Icons.insert_chart_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      label: 'Collection Rate',
                      value: '${(_collectionRate * 100).toInt()}%',
                    )),
                  ]),

                  const SizedBox(height: 24),

                  // ── Monthly bar chart ───────────────────────
                  _SectionTitle('Monthly Collection (Last 6 Months)'),
                  const SizedBox(height: 12),
                  _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_monthStats.isEmpty)
                      _EmptyState(icon: Icons.bar_chart_rounded, message: 'No payment data yet')
                    else ...[
                      SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _monthStats.map((m) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                Text('${(m.value * 100).toInt()}%',
                                    style: ts(9, FontWeight.w700, m.isCurrentMonth ? kPrimary : kSlate400)),
                                const SizedBox(height: 4),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  height: m.value == 0 ? 4 : m.value * 110,
                                  decoration: BoxDecoration(
                                    color: m.isCurrentMonth ? kPrimary : kPrimary.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ]),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _monthStats.map((m) => Text(m.label,
                            style: ts(10, FontWeight.w700, m.isCurrentMonth ? kPrimary : kSlate400))).toList(),
                      ),
                    ],
                  ])),

                  const SizedBox(height: 24),

                  // ── Payment by class ────────────────────────
                  _SectionTitle('Payment by Class'),
                  const SizedBox(height: 12),
                  _Card(child: _classes.isEmpty
                      ? _EmptyState(icon: Icons.class_outlined, message: 'No classes added yet')
                      : Column(
                          children: _classes.map((c) {
                            final paid = (c.paymentProgress * c.studentCount).round();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(children: [
                                    Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: kPrimary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(child: Text(c.name.substring(0, 1),
                                          style: ts(13, FontWeight.w800, kPrimary))),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(c.name, style: ts(13, FontWeight.w700, kSlate900)),
                                      Text('$paid / ${c.studentCount} paid',
                                          style: ts(11, FontWeight.w500, kSlate400)),
                                    ]),
                                  ]),
                                  Text('${(c.paymentProgress * 100).toInt()}%',
                                      style: ts(14, FontWeight.w800, kPrimary)),
                                ]),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: c.paymentProgress, minHeight: 8,
                                    backgroundColor: kSlate100,
                                    valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                                  ),
                                ),
                              ]),
                            );
                          }).toList(),
                        )),

                  const SizedBox(height: 24),

                  // ── Revenue breakdown ───────────────────────
                  _SectionTitle('Revenue Breakdown'),
                  const SizedBox(height: 12),
                  _Card(child: _classes.isEmpty
                      ? _EmptyState(icon: Icons.payments_outlined, message: 'No revenue data yet')
                      : Column(
                          children: _classes.map((c) {
                            final paid = (c.paymentProgress * c.studentCount).round();
                            final rev = paid * c.feeAmount;
                            final maxRev = _classes.fold(0.0, (m, x) =>
                                (x.paymentProgress * x.studentCount).round() * x.feeAmount > m
                                    ? (x.paymentProgress * x.studentCount).round() * x.feeAmount
                                    : m);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                SizedBox(width: 48,
                                    child: Text(c.name, style: ts(12, FontWeight.w700, kSlate500))),
                                const SizedBox(width: 8),
                                Expanded(child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: maxRev == 0 ? 0 : rev / maxRev,
                                    minHeight: 10,
                                    backgroundColor: kSlate100,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                                  ),
                                )),
                                const SizedBox(width: 10),
                                Text(_fmt(rev), style: ts(12, FontWeight.w700, kSlate900)),
                              ]),
                            );
                          }).toList(),
                        )),

                  const SizedBox(height: 24),

                  // ── Recent payments ─────────────────────────
                  _SectionTitle('Top Paying Students'),
                  const SizedBox(height: 12),
                  _Card(child: _recentPayments.isEmpty
                      ? _EmptyState(icon: Icons.receipt_long_outlined, message: 'No payments recorded yet')
                      : Column(
                          children: List.generate(_recentPayments.length, (i) => Column(children: [
                            if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: kPrimary.withOpacity(0.1),
                                  child: Text(
                                    _recentPayments[i].name.trim().split(' ').map((p) => p[0]).take(2).join(),
                                    style: ts(12, FontWeight.w700, kPrimary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_recentPayments[i].name, style: ts(13, FontWeight.w700, kSlate900)),
                                  Text('${_recentPayments[i].className} · ${_recentPayments[i].date}',
                                      style: ts(11, FontWeight.w400, kSlate500)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: kPrimary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(_fmtFull(_recentPayments[i].amount),
                                      style: ts(12, FontWeight.w700, kPrimary)),
                                ),
                              ]),
                            ),
                          ])),
                        )),
                ]),
              ),
            ),
          ),
        ]),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _MonthStat {
  final String label;
  final double value;
  final bool isCurrentMonth;
  const _MonthStat({required this.label, required this.value, required this.isCurrentMonth});
}

class _RecentPayment {
  final String name, className, date;
  final double amount;
  const _RecentPayment({required this.name, required this.className, required this.amount, required this.date});
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title, style: ts(16, FontWeight.w800, kSlate900));
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String label, value;
  const _StatCard({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(height: 12),
      Text(label, style: ts(11, FontWeight.w600, kSlate400)),
      const SizedBox(height: 4),
      Text(value, style: ts(22, FontWeight.w800, kSlate900)),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(children: [
      Icon(icon, color: kSlate400, size: 40),
      const SizedBox(height: 10),
      Text(message, style: ts(13, FontWeight.w500, kSlate400)),
    ]),
  );
}
