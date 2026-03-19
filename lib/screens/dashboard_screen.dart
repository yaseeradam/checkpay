import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';
import '../services/app_prefs.dart';
import 'classes_screen.dart';
import 'reports_screen.dart';
import 'app_settings_screen.dart';
import 'students_screen.dart';
import 'add_student_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  void _setNav(int i) {
    // Reload dashboard data when switching back to home tab
    if (i == 0 && _navIndex != 0) {
      setState(() => _navIndex = i);
      _dashboardKey.currentState?.reload();
    } else {
      setState(() => _navIndex = i);
    }
  }

  final _dashboardKey = GlobalKey<_DashboardBodyState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardBody(key: _dashboardKey, onNavTap: _setNav),
      ClassesScreen(onRefreshDashboard: () {
        _dashboardKey.currentState?.reload();
      }),
      const ReportsScreen(),
      const AppSettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: kBackground,
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: _BottomNav(currentIndex: _navIndex, onTap: _setNav),
    );
  }
}

// ── Dashboard Body ────────────────────────────────────────────────────────────
class _DashboardBody extends StatefulWidget {
  final ValueChanged<int> onNavTap;
  const _DashboardBody({super.key, required this.onNavTap});
  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  File? _schoolLogo;
  final _picker = ImagePicker();
  List<SchoolClass> _classes = [];
  int _totalStudents = 0;
  int _paidStudents = 0;
  String _schoolName = 'My School';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void reload() => _loadData();

  Future<void> _loadData() async {
    final classes = await DB.getClasses();
    final name = await AppPrefs.getSchoolName();
    final logoPath = await AppPrefs.getLogoPath();
    int total = 0, paid = 0;
    for (final c in classes) {
      total += c.studentCount;
      paid += (c.paymentProgress * c.studentCount).round();
    }
    if (mounted) setState(() {
      _classes = classes;
      _totalStudents = total;
      _paidStudents = paid;
      _schoolName = name;
      if (logoPath != null && File(logoPath).existsSync()) {
        _schoolLogo = File(logoPath);
      } else {
        _schoolLogo = null;
      }
    });
  }

  Future<void> _pickLogo() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 16),
          Text('School Logo', style: ts(16, FontWeight.w700, kSlate900)),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded, color: kPrimary)),
            title: Text('Take Photo', style: ts(14, FontWeight.w600, kSlate900)),
            onTap: () async {
              Navigator.pop(context);
              final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (img != null) await _saveLogo(img);
            },
          ),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF3B82F6))),
            title: Text('Choose from Gallery', style: ts(14, FontWeight.w600, kSlate900)),
            onTap: () async {
              Navigator.pop(context);
              final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (img != null) await _saveLogo(img);
            },
          ),
          if (_schoolLogo != null) ListTile(
            leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600)),
            title: Text('Remove Logo', style: ts(14, FontWeight.w600, Colors.red.shade600)),
            onTap: () async {
              Navigator.pop(context);
              await AppPrefs.setLogoPath(null);
              setState(() => _schoolLogo = null);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// Save the picked image to a persistent app directory so it survives restarts.
  Future<void> _saveLogo(XFile img) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(img.path);
    final dest = p.join(dir.path, 'school_logo$ext');
    await File(img.path).copy(dest);
    await AppPrefs.setLogoPath(dest);
    if (mounted) setState(() => _schoolLogo = File(dest));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  int get _unpaidStudents => _totalStudents - _paidStudents;
  double get _collectionRate => _totalStudents == 0 ? 0 : _paidStudents / _totalStudents;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // ── Hero Header ──────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPrimaryDark, kPrimary, kPrimaryLight],
                  stops: [0.0, 0.6, 1.0],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Top row — logo only (no notification bell)
                    Row(children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: Stack(children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                            ),
                            child: _schoolLogo != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(14),
                                    child: Image.file(_schoolLogo!, fit: BoxFit.cover))
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.asset('lib/public/android-chrome-192x192.png', fit: BoxFit.cover)),
                          ),
                          Positioned(bottom: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded, size: 9, color: kPrimary),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_schoolName, style: ts(16, FontWeight.w800, Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('Fee Management System', style: ts(11, FontWeight.w500, Colors.white70)),
                      ])),
                    ]),
                    const SizedBox(height: 24),
                    Text(_greeting(), style: ts(13, FontWeight.w500, Colors.white70)),
                    const SizedBox(height: 2),
                    Text('Welcome back! 👋', style: ts(26, FontWeight.w800, Colors.white)),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(children: [
                      _HeroPill(icon: Icons.groups_rounded, label: 'Students', value: '$_totalStudents'),
                      const SizedBox(width: 10),
                      _HeroPill(icon: Icons.check_circle_rounded, label: 'Paid', value: '$_paidStudents', color: const Color(0xFFD1E4FF)),
                      const SizedBox(width: 10),
                      _HeroPill(icon: Icons.pending_rounded, label: 'Unpaid', value: '$_unpaidStudents', color: const Color(0xFFFECACA)),
                    ]),
                  ]),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Collection Rate Card ──────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.trending_up_rounded, color: kPrimary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('Collection Rate', style: ts(15, FontWeight.w700, kSlate900)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(999)),
                      child: Text('This Month', style: ts(11, FontWeight.w700, kPrimary)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text('${(_collectionRate * 100).toInt()}%', style: ts(40, FontWeight.w800, kSlate900)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$_paidStudents of $_totalStudents students paid', style: ts(12, FontWeight.w500, kSlate500)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _collectionRate, minHeight: 10,
                          backgroundColor: kSlate100,
                          valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                        ),
                      ),
                    ])),
                  ]),
                ]),
              ),

              const SizedBox(height: 28),

              // ── Quick Actions ─────────────────────────────
              Text('Quick Actions', style: ts(17, FontWeight.w800, kSlate900)),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.2,
                children: [
                  _QuickAction(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Mark Payments',
                    subtitle: 'Record fees',
                    gradient: const [Color(0xFF335BBD), Color(0xFF5B7FD4)],
                    onTap: () => widget.onNavTap(1),
                  ),
                  _QuickAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Add Student',
                    subtitle: 'New enrollment',
                    gradient: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudentScreen()));
                      _loadData();
                    },
                  ),
                  _QuickAction(
                    icon: Icons.insert_chart_rounded,
                    label: 'View Reports',
                    subtitle: 'Analytics',
                    gradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    onTap: () => widget.onNavTap(2),
                  ),
                  _QuickAction(
                    icon: Icons.price_change_rounded,
                    label: 'Fee Settings',
                    subtitle: 'Manage rates',
                    gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Classes ───────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Classes', style: ts(17, FontWeight.w800, kSlate900)),
                TextButton.icon(
                  onPressed: () => widget.onNavTap(1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: kPrimary),
                  label: Text('See All', style: ts(13, FontWeight.w700, kPrimary)),
                ),
              ]),
              const SizedBox(height: 12),
              if (_classes.isEmpty)
                _EmptyClasses(onTap: () => widget.onNavTap(1))
              else
                ..._classes.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassCard(schoolClass: c, onRefresh: _loadData),
                )),

              const SizedBox(height: 100),
            ])),
          ),
        ],
      ),
    );
  }
}

class _EmptyClasses extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyClasses({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kSlate100, width: 2),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: kPrimary.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.class_outlined, color: kPrimary, size: 32),
        ),
        const SizedBox(height: 12),
        Text('No classes yet', style: ts(15, FontWeight.w700, kSlate900)),
        const SizedBox(height: 4),
        Text('Tap to add your first class', style: ts(12, FontWeight.w400, kSlate500)),
      ]),
    ),
  );
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _HeroPill extends StatelessWidget {
  final IconData icon; final String label, value; final Color? color;
  const _HeroPill({required this.icon, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color != null ? Colors.transparent : Colors.white.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color != null ? kSlate900 : Colors.white, size: 18),
        const SizedBox(height: 6),
        Text(value, style: ts(20, FontWeight.w800, color != null ? kSlate900 : Colors.white)),
        Text(label, style: ts(10, FontWeight.w600, color != null ? kSlate500 : Colors.white70)),
      ]),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: ts(13, FontWeight.w700, Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle, style: ts(10, FontWeight.w500, Colors.white70),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.5), size: 14),
      ]),
    ),
  );
}

class _ClassCard extends StatelessWidget {
  final SchoolClass schoolClass;
  final VoidCallback onRefresh;
  const _ClassCard({required this.schoolClass, required this.onRefresh});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentsScreen(schoolClass: schoolClass)));
      onRefresh();
    },
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(schoolClass.name.substring(0, 1), style: ts(20, FontWeight.w800, kPrimary))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(schoolClass.name, style: ts(15, FontWeight.w700, kSlate900)),
          const SizedBox(height: 2),
          Text('${schoolClass.studentCount} students · ${schoolClass.section}', style: ts(12, FontWeight.w400, kSlate500)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: schoolClass.paymentProgress, minHeight: 6,
                backgroundColor: kSlate100, valueColor: const AlwaysStoppedAnimation<Color>(kPrimary)),
          ),
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(schoolClass.paymentProgress * 100).toInt()}%', style: ts(16, FontWeight.w800, kPrimary)),
          Text('paid', style: ts(11, FontWeight.w500, kSlate400)),
        ]),
      ]),
    ),
  );
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex; final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.space_dashboard_rounded, Icons.space_dashboard_outlined, 'Home'),
      (Icons.menu_book_rounded, Icons.menu_book_outlined, 'Classes'),
      (Icons.insert_chart_rounded, Icons.insert_chart_outlined_rounded, 'Reports'),
      (Icons.manage_accounts_rounded, Icons.manage_accounts_outlined, 'Settings'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? kPrimary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(active ? items[i].$1 : items[i].$2, color: active ? kPrimary : kSlate400, size: 22),
                if (active) ...[
                  const SizedBox(width: 6),
                  Text(items[i].$3, style: ts(12, FontWeight.w700, kPrimary)),
                ],
              ]),
            ),
          );
        }),
      ),
    );
  }
}
