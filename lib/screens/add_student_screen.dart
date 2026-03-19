import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../models.dart';
import '../services/db_helper.dart';
import '../widgets/result_modal.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student;
  final String? defaultClass;
  const AddStudentScreen({super.key, this.student, this.defaultClass});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedClass;
  File? _photo;
  final _picker = ImagePicker();
  List<String> _classes = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.defaultClass;
    if (widget.student != null) {
      _nameCtrl.text = widget.student!.name;
      _idCtrl.text = widget.student!.id;
      _selectedClass = widget.student!.className;
      if (widget.student!.photoPath != null) _photo = File(widget.student!.photoPath!);
    }
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final classes = await DB.getClasses();
    if (mounted) setState(() => _classes = classes.map((c) => c.name).toList());
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _idCtrl.dispose();
    _parentCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final t = _nameCtrl.text.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return t.substring(0, t.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kSlate100, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 16),
          Text('Student Photo', style: ts(16, FontWeight.w700, kSlate900)),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded, color: kPrimary)),
            title: Text('Take Photo', style: ts(14, FontWeight.w600, kSlate900)),
            onTap: () async {
              Navigator.pop(context);
              final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (img != null) setState(() => _photo = File(img.path));
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
              if (img != null) setState(() => _photo = File(img.path));
            },
          ),
          if (_photo != null) ListTile(
            leading: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600)),
            title: Text('Remove Photo', style: ts(14, FontWeight.w600, Colors.red.shade600)),
            onTap: () { Navigator.pop(context); setState(() => _photo = null); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter student name', style: ts(13, FontWeight.w500, Colors.white)),
            backgroundColor: kSlate900, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      return;
    }
    if (_idCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter student ID', style: ts(13, FontWeight.w500, Colors.white)),
            backgroundColor: kSlate900, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      return;
    }
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a class', style: ts(13, FontWeight.w500, Colors.white)),
            backgroundColor: kSlate900, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      return;
    }
    setState(() => _saving = true);
    final student = Student(
      id: _idCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      className: _selectedClass!,
      photoPath: _photo?.path,
    );
    try {
      await DB.addStudent(student);
      if (mounted) {
        Navigator.pop(context);
        showResultModal(context,
          isSuccess: true,
          title: 'Student Added!',
          message: '${_nameCtrl.text.trim()} has been enrolled successfully.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().contains('DUPLICATE_ID')
          ? 'Student ID already exists. Use a unique ID.'
          : 'Failed to save student. Please try again.';
      showResultModal(context,
        isSuccess: false,
        title: 'Error',
        message: msg,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.student != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      body: Stack(children: [
        Positioned(top: -60, left: -60, child: _Blob(kPrimary.withOpacity(0.12), 300)),
        Positioned(bottom: -60, right: -60, child: _Blob(kPrimary.withOpacity(0.08), 250)),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _CircleBtn(icon: Icons.arrow_back_rounded, color: kSlate900, bg: Colors.white.withOpacity(0.5),
                  onTap: () => Navigator.pop(context)),
              Text(isEdit ? 'Edit Student' : 'Add Student', style: ts(18, FontWeight.w800, kSlate900)),
              _saving
                  ? const SizedBox(width: 40, height: 40,
                      child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)))
                  : _CircleBtn(icon: Icons.check_rounded, color: Colors.white, bg: kPrimary, onTap: _save),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)],
                ),
                child: Column(children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: kPrimary.withOpacity(0.1),
                        backgroundImage: _photo != null ? FileImage(_photo!) : null,
                        child: _photo == null ? Text(_initials, style: ts(32, FontWeight.w700, kPrimary)) : null,
                      ),
                      Positioned(bottom: 0, right: 0,
                          child: Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 8)]),
                            child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('Student Profile', style: ts(15, FontWeight.w600, kSlate900)),
                  Text(_photo != null ? 'Photo selected ✓' : 'Tap to upload a photo',
                      style: ts(12, FontWeight.w400, _photo != null ? kPrimary : kSlate500)),
                  const SizedBox(height: 28),
                  _Field(ctrl: _nameCtrl, label: 'Full Name', hint: 'Enter student\'s full name',
                      icon: Icons.person_outline_rounded, onChanged: (_) => setState(() {})),
                  const SizedBox(height: 16),
                  _Field(ctrl: _idCtrl, label: 'Student ID', hint: 'e.g. CP-2024-001', icon: Icons.badge_outlined),
                  const SizedBox(height: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Class/Grade', style: ts(13, FontWeight.w600, kSlate500)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.5))),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedClass,
                        hint: Text('Select Grade', style: ts(14, FontWeight.w400, kSlate400)),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.school_outlined, color: kSlate400),
                          border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        items: _classes.map((c) => DropdownMenuItem(value: c,
                            child: Text(c, style: ts(14, FontWeight.w400, kSlate900)))).toList(),
                        onChanged: (v) => setState(() => _selectedClass = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _Field(ctrl: _parentCtrl, label: 'Parent/Guardian Name', hint: 'Enter parent or guardian name',
                      icon: Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _Field(ctrl: _phoneCtrl, label: 'Phone Number', hint: '+234 800 000 0000',
                      icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 28),
                  SizedBox(width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          elevation: 2, shadowColor: kPrimary.withOpacity(0.3)),
                      icon: const Icon(Icons.person_add_rounded),
                      label: Text(isEdit ? 'Save Changes' : 'Save Student', style: ts(15, FontWeight.w700, Colors.white)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const _Field({required this.ctrl, required this.label, required this.hint,
    required this.icon, this.keyboardType, this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: ts(13, FontWeight.w600, kSlate500)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl, keyboardType: keyboardType, onChanged: onChanged,
      style: ts(14, FontWeight.w400, kSlate900),
      decoration: InputDecoration(
        hintText: hint, hintStyle: ts(14, FontWeight.w400, kSlate400),
        prefixIcon: Icon(icon, color: kSlate400),
        filled: true, fillColor: Colors.white.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  ]);
}

class _CircleBtn extends StatelessWidget {
  final IconData icon; final Color color, bg; final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.color, required this.bg, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3))),
      child: Icon(icon, color: color)),
  );
}

class _Blob extends StatelessWidget {
  final Color color; final double size;
  const _Blob(this.color, this.size);
  @override
  Widget build(BuildContext context) => Container(width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
