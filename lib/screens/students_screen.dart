import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';
import 'payment_history_screen.dart';
import 'add_student_screen.dart';

class StudentsScreen extends StatefulWidget {
  final SchoolClass schoolClass;
  const StudentsScreen({super.key, required this.schoolClass});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchCtrl = TextEditingController();
  List<Student> _students = [];
  List<Student> _filtered = [];
  List<String> _allClasses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _load();
  }

  Future<void> _load() async {
    final students = await DB.getStudents(widget.schoolClass.name);
    final classes = await DB.getClasses();
    if (mounted) setState(() {
      _students = students;
      _filtered = students;
      _allClasses = classes.map((c) => c.name).toList();
      _loading = false;
    });
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _students
          : _students.where((s) => s.name.toLowerCase().contains(q) || s.id.contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showEditSheet(Student s) {
    final nameCtrl = TextEditingController(text: s.name);
    final parentCtrl = TextEditingController(text: s.parentName ?? '');
    final phoneCtrl = TextEditingController(text: s.phone ?? '');
    File? photo = s.photoPath != null ? File(s.photoPath!) : null;
    String selectedClass = s.className;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setS) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_rounded, color: kPrimary, size: 22)),
                const SizedBox(width: 12),
                Text('Edit Student', style: ts(18, FontWeight.w800, kSlate900)),
              ]),
              const SizedBox(height: 24),
              // Photo picker
              Center(child: GestureDetector(
                onTap: () async {
                  showModalBottomSheet(
                    context: ctx,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.camera_alt_rounded, color: kPrimary),
                        title: Text('Take Photo', style: ts(14, FontWeight.w600, kSlate900)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                          if (img != null) setS(() => photo = File(img.path));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF3B82F6)),
                        title: Text('Choose from Gallery', style: ts(14, FontWeight.w600, kSlate900)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (img != null) setS(() => photo = File(img.path));
                        },
                      ),
                      if (photo != null) ListTile(
                        leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
                        title: Text('Remove Photo', style: ts(14, FontWeight.w600, Colors.red.shade600)),
                        onTap: () { Navigator.pop(ctx); setS(() => photo = null); },
                      ),
                      const SizedBox(height: 8),
                    ])),
                  );
                },
                child: Stack(children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: kPrimary.withOpacity(0.1),
                    backgroundImage: photo != null ? FileImage(photo!) : null,
                    child: photo == null ? Text(s.initials, style: ts(26, FontWeight.w700, kPrimary)) : null,
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 14),
                  )),
                ]),
              )),
              const SizedBox(height: 8),
              Center(child: Text('Tap photo to change', style: ts(11, FontWeight.w500, kSlate400))),
              const SizedBox(height: 20),
              _SheetField(ctrl: nameCtrl, label: 'Full Name', hint: 'Student full name', icon: Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _SheetField(ctrl: parentCtrl, label: 'Parent / Guardian', hint: 'Parent or guardian name', icon: Icons.people_outline_rounded),
              const SizedBox(height: 14),
              _SheetField(ctrl: phoneCtrl, label: 'Phone Number', hint: '+234 800 000 0000',
                  icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              Text('Class', style: ts(12, FontWeight.w600, kSlate500)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(14)),
                child: DropdownButtonFormField<String>(
                  value: selectedClass,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.school_outlined, color: kSlate400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  items: _allClasses.map((c) => DropdownMenuItem(value: c,
                      child: Text(c, style: ts(14, FontWeight.w500, kSlate900)))).toList(),
                  onChanged: (v) => setS(() => selectedClass = v ?? selectedClass),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final updated = Student(
                      id: s.id,
                      name: nameCtrl.text.trim(),
                      className: selectedClass,
                      photoPath: photo?.path,
                      parentName: parentCtrl.text.trim().isEmpty ? null : parentCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    );
                    await DB.updateStudent(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: Text('Save Changes', style: ts(15, FontWeight.w700, Colors.white)),
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
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryDark, kPrimary, kPrimaryLight],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    Text(widget.schoolClass.name, style: ts(20, FontWeight.w800, Colors.white)),
                    Text('${_students.length} students enrolled',
                        style: ts(12, FontWeight.w500, Colors.white.withOpacity(0.75))),
                  ])),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchCtrl,
                  style: ts(14, FontWeight.w400, kSlate900),
                  decoration: InputDecoration(
                    hintText: 'Search for a student...',
                    hintStyle: ts(14, FontWeight.w400, kSlate400),
                    prefixIcon: const Icon(Icons.search_rounded, color: kSlate400),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary)))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _StudentRow(
                student: _filtered[i],
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => PaymentHistoryScreen(student: _filtered[i])));
                  _load();
                },
                onEdit: () => _showEditSheet(_filtered[i]),
                onDelete: () async {
                  await DB.deleteStudent(_filtered[i].id);
                  _load();
                },
              ),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => AddStudentScreen(defaultClass: widget.schoolClass.name)));
          _load();
        },
        backgroundColor: kPrimary, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Student', style: ts(14, FontWeight.w700, Colors.white)),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StudentRow({required this.student, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(student.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Student', style: ts(16, FontWeight.w700, kSlate900)),
            content: Text('Remove ${student.name}? This cannot be undone.', style: ts(13, FontWeight.w400, kSlate500)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: ts(14, FontWeight.w600, kSlate500))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                child: Text('Delete', style: ts(14, FontWeight.w700, Colors.white)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: kSlate100,
              backgroundImage: student.photoPath != null ? FileImage(File(student.photoPath!)) : null,
              child: student.photoPath == null
                  ? Text(student.initials, style: ts(13, FontWeight.w700, kSlate500))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.name, style: ts(15, FontWeight.w600, kSlate900)),
              const SizedBox(height: 2),
              Text('ID: ${student.id}', style: ts(11, FontWeight.w600, kSlate400, letterSpacing: 0.5)),
              if (student.parentName != null) ...[
                const SizedBox(height: 2),
                Text('Parent: ${student.parentName}', style: ts(11, FontWeight.w500, kSlate400)),
              ],
            ])),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, size: 16, color: kPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: student.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(student.isPaid ? 'Paid' : 'Unpaid',
                  style: ts(11, FontWeight.w700, student.isPaid ? const Color(0xFF15803D) : const Color(0xFFB91C1C), letterSpacing: 0.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _SheetField({required this.ctrl, required this.label, required this.hint,
      required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: ts(12, FontWeight.w600, kSlate500)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: ts(14, FontWeight.w500, kSlate900),
      decoration: InputDecoration(
        hintText: hint, hintStyle: ts(14, FontWeight.w400, kSlate400),
        prefixIcon: Icon(icon, color: kSlate400),
        filled: true, fillColor: kSlate100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  ]);
}
