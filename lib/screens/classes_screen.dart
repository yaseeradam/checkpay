import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';
import '../widgets/result_modal.dart';
import 'students_screen.dart';
import 'payment_screen.dart';

class ClassesScreen extends StatefulWidget {
  final VoidCallback? onRefreshDashboard;
  const ClassesScreen({super.key, this.onRefreshDashboard});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> with SingleTickerProviderStateMixin {
  List<SchoolClass> _classes = [];
  bool _loading = true;
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final classes = await DB.getClasses();
    if (mounted) setState(() { _classes = classes; _loading = false; });
  }

  List<SchoolClass> get _junior => _classes
      .where((c) => c.section.toLowerCase().contains('junior'))
      .where((c) => _query.isEmpty || c.name.toLowerCase().contains(_query))
      .toList();

  List<SchoolClass> get _senior => _classes
      .where((c) => c.section.toLowerCase().contains('senior'))
      .where((c) => _query.isEmpty || c.name.toLowerCase().contains(_query))
      .toList();

  List<SchoolClass> get _all => _classes
      .where((c) => _query.isEmpty || c.name.toLowerCase().contains(_query))
      .toList();

  int get _totalStudents => _classes.fold(0, (s, c) => s + c.studentCount);
  int get _totalPaid => _classes.fold(0, (s, c) => s + (c.paymentProgress * c.studentCount).round());

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    String section = 'Junior Section';
    double fee = 150000;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.class_rounded, color: kPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Add New Class', style: ts(18, FontWeight.w800, kSlate900)),
              ]),
              const SizedBox(height: 24),
              Text('Class Name', style: ts(12, FontWeight.w600, kSlate500)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: ts(14, FontWeight.w600, kSlate900),
                decoration: InputDecoration(
                  hintText: 'e.g. JSS 4, SS 3',
                  hintStyle: ts(14, FontWeight.w400, kSlate400),
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, color: kSlate400),
                  filled: true, fillColor: kSlate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kPrimary, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Section', style: ts(12, FontWeight.w600, kSlate500)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setS(() => section = 'Junior Section'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: section == 'Junior Section' ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.school_rounded, size: 16,
                            color: section == 'Junior Section' ? Colors.white : kSlate500),
                        const SizedBox(width: 6),
                        Text('Junior', style: ts(13, FontWeight.w700,
                            section == 'Junior Section' ? Colors.white : kSlate500)),
                      ]),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setS(() => section = 'Senior Section'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: section == 'Senior Section' ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.history_edu_rounded, size: 16,
                            color: section == 'Senior Section' ? Colors.white : kSlate500),
                        const SizedBox(width: 6),
                        Text('Senior', style: ts(13, FontWeight.w700,
                            section == 'Senior Section' ? Colors.white : kSlate500)),
                      ]),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Term Fee (₦)', style: ts(12, FontWeight.w600, kSlate500)),
              const SizedBox(height: 6),
              TextField(
                keyboardType: TextInputType.number,
                style: ts(14, FontWeight.w600, kSlate900),
                onChanged: (v) => fee = double.tryParse(v) ?? 150000,
                decoration: InputDecoration(
                  hintText: '150000',
                  hintStyle: ts(14, FontWeight.w400, kSlate400),
                  prefixIcon: const Icon(Icons.payments_outlined, color: kSlate400),
                  prefixText: '₦ ',
                  prefixStyle: ts(14, FontWeight.w600, kSlate900),
                  filled: true, fillColor: kSlate100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kPrimary, width: 2)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await DB.addClass(nameCtrl.text.trim(), section, fee);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                      widget.onRefreshDashboard?.call();
                      if (mounted) {
                        showResultModal(context,
                          isSuccess: true,
                          title: 'Class Created!',
                          message: '${nameCtrl.text.trim()} has been added successfully.',
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showResultModal(context,
                          isSuccess: false,
                          title: 'Failed',
                          message: 'Could not create class. Please try again.',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Create Class', style: ts(15, FontWeight.w700, Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [kPrimaryDark, kPrimary],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Classes', style: ts(26, FontWeight.w800, Colors.white)),
                        Text('${_classes.length} classes · $_totalStudents students',
                            style: ts(13, FontWeight.w500, Colors.white70)),
                      ])),
                      // Stats pills
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('$_totalPaid paid', style: ts(13, FontWeight.w700, Colors.white)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: ts(14, FontWeight.w500, kSlate900),
                        decoration: InputDecoration(
                          hintText: 'Search classes...',
                          hintStyle: ts(14, FontWeight.w400, kSlate400),
                          prefixIcon: const Icon(Icons.search_rounded, color: kSlate400, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.close_rounded, color: kSlate400, size: 18),
                                  onPressed: () => _searchCtrl.clear())
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tabs
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Junior'),
                      Tab(text: 'Senior'),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _ClassList(classes: _all, onRefresh: _load, onRefreshDashboard: widget.onRefreshDashboard),
                  _ClassList(classes: _junior, onRefresh: _load, onRefreshDashboard: widget.onRefreshDashboard),
                  _ClassList(classes: _senior, onRefresh: _load, onRefreshDashboard: widget.onRefreshDashboard),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClassDialog,
        backgroundColor: kPrimary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Class', style: ts(14, FontWeight.w700, Colors.white)),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Class List ────────────────────────────────────────────────────────────────
class _ClassList extends StatelessWidget {
  final List<SchoolClass> classes;
  final VoidCallback onRefresh;
  final VoidCallback? onRefreshDashboard;
  const _ClassList({required this.classes, required this.onRefresh, this.onRefreshDashboard});

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.class_outlined, color: kPrimary, size: 36),
          ),
          const SizedBox(height: 16),
          Text('No classes here', style: ts(16, FontWeight.w700, kSlate900)),
          const SizedBox(height: 4),
          Text('Add a class using the button below', style: ts(13, FontWeight.w400, kSlate500)),
        ]),
      );
    }
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        itemCount: classes.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ClassCard(schoolClass: classes[i], onRefresh: onRefresh, onRefreshDashboard: onRefreshDashboard),
        ),
      ),
    );
  }
}

// ── Class Card ────────────────────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final SchoolClass schoolClass;
  final VoidCallback onRefresh;
  final VoidCallback? onRefreshDashboard;
  const _ClassCard({required this.schoolClass, required this.onRefresh, this.onRefreshDashboard});

  // Pick a unique accent color per class name
  Color get _accent {
    const colors = [
      Color(0xFF21C45E), Color(0xFF3B82F6), Color(0xFF8B5CF6),
      Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
    ];
    return colors[schoolClass.name.hashCode.abs() % colors.length];
  }

  IconData get _icon {
    if (schoolClass.section.toLowerCase().contains('junior')) return Icons.school_rounded;
    return Icons.history_edu_rounded;
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
    final paidCount = (schoolClass.paymentProgress * schoolClass.studentCount).round();
    final unpaidCount = schoolClass.studentCount - paidCount;
    final progress = schoolClass.paymentProgress;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _accent.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        // ── Top section ──
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon badge
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_accent, _accent.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Icon(_icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(schoolClass.name, style: ts(20, FontWeight.w800, kSlate900)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(schoolClass.section, style: ts(10, FontWeight.w700, _accent)),
                ),
                const SizedBox(width: 8),
                Text('${_fmt(schoolClass.feeAmount)}/term', style: ts(11, FontWeight.w500, kSlate400)),
              ]),
            ])),
            // Delete button
            GestureDetector(
              onTap: () => _confirmDelete(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded, color: kSlate400, size: 18),
              ),
            ),
          ]),
        ),

        // ── Stats row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _StatChip(icon: Icons.people_rounded, label: 'Total', value: '${schoolClass.studentCount}', color: kSlate500),
            const SizedBox(width: 8),
            _StatChip(icon: Icons.check_circle_rounded, label: 'Paid', value: '$paidCount', color: kPrimary),
            const SizedBox(width: 8),
            _StatChip(icon: Icons.cancel_rounded, label: 'Unpaid', value: '$unpaidCount', color: const Color(0xFFEF4444)),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Progress bar ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Payment Progress', style: ts(11, FontWeight.w600, kSlate400)),
              Text('${(progress * 100).toInt()}%', style: ts(12, FontWeight.w800, _accent)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress, minHeight: 8,
                backgroundColor: kSlate100,
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Action buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            // View Students
            Expanded(child: GestureDetector(
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StudentsScreen(schoolClass: schoolClass)));
                onRefresh();
                onRefreshDashboard?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kSlate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.people_alt_rounded, size: 16, color: kSlate500),
                  const SizedBox(width: 6),
                  Text('Students', style: ts(13, FontWeight.w700, kSlate500)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            // Mark Payments — the working pay button
            Expanded(child: GestureDetector(
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PaymentScreen(schoolClass: schoolClass)));
                onRefresh();
                onRefreshDashboard?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_accent, _accent.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.how_to_reg_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Mark Paid', style: ts(13, FontWeight.w700, Colors.white)),
                ]),
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade600, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Delete Class', style: ts(20, FontWeight.w800, kSlate900)),
            const SizedBox(height: 12),
            Text(
              'Delete "${schoolClass.name}"? All students and payment records in this class will be permanently removed.',
              textAlign: TextAlign.center,
              style: ts(13, FontWeight.w400, kSlate500, height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await DB.deleteClass(schoolClass.id);
                    if (context.mounted) Navigator.pop(context);
                    onRefresh();
                    onRefreshDashboard?.call();
                    if (context.mounted) {
                      showResultModal(context,
                        isSuccess: true,
                        title: 'Class Deleted',
                        message: '"${schoolClass.name}" has been removed.',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      showResultModal(context,
                        isSuccess: false,
                        title: 'Delete Failed',
                        message: 'Could not delete the class. Please try again.',
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 2,
                  shadowColor: Colors.red.withOpacity(0.3),
                ),
                child: Text('Delete Class', style: ts(15, FontWeight.w700, Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: kSlate100,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text('Cancel', style: ts(15, FontWeight.w700, kSlate500)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: ts(15, FontWeight.w800, kSlate900)),
        Text(label, style: ts(10, FontWeight.w600, kSlate400)),
      ]),
    ),
  );
}
