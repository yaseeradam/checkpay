import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _load();
  }

  Future<void> _load() async {
    final students = await DB.getStudents(widget.schoolClass.name);
    if (mounted) setState(() { _students = students; _filtered = students; _loading = false; });
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
  final VoidCallback onDelete;
  const _StudentRow({required this.student, required this.onTap, required this.onDelete});

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
            ])),
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
