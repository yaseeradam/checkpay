import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/app_prefs.dart';
import '../services/db_helper.dart';
import '../widgets/result_modal.dart';
import 'settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _schoolName = 'My School';
  bool _exporting = false;
  bool _importing = false;
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bio = await AppPrefs.getBiometric();
    final name = await AppPrefs.getSchoolName();
    bool canCheck = false;
    try {
      canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {}
    if (mounted) setState(() { _biometricEnabled = bio; _schoolName = name; _biometricAvailable = canCheck; });
  }

  Future<void> _toggleBiometric(bool val) async {
    if (val) {
      final confirmed = await _showPinConfirmDialog();
      if (!confirmed) return;
    }
    await AppPrefs.setBiometric(val);
    setState(() => _biometricEnabled = val);
    if (mounted) {
      showResultModal(context,
        isSuccess: true,
        title: val ? 'Biometric Enabled' : 'Biometric Disabled',
        message: val ? 'You can now use fingerprint or face to unlock.' : 'Biometric login has been turned off.',
      );
    }
  }

  Future<bool> _showPinConfirmDialog() async {
    final ctrl = TextEditingController();
    bool confirmed = false;
    await showDialog(
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
                color: kPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pin_outlined, color: kPrimary, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Confirm PIN', style: ts(20, FontWeight.w800, kSlate900)),
            const SizedBox(height: 8),
            Text('Enter your current PIN to continue.',
                textAlign: TextAlign.center,
                style: ts(13, FontWeight.w400, kSlate500)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl, obscureText: true,
              keyboardType: TextInputType.number, maxLength: 4,
              textAlign: TextAlign.center,
              style: ts(24, FontWeight.w800, kSlate900, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: ts(24, FontWeight.w400, kSlate400, letterSpacing: 8),
                counterText: '',
                filled: true, fillColor: kSlate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final ok = await AppPrefs.checkPin(ctrl.text);
                  if (ok) { confirmed = true; nav.pop(); }
                  else {
                    nav.pop();
                    if (mounted) {
                      showResultModal(context,
                        isSuccess: false,
                        title: 'Incorrect PIN',
                        message: 'The PIN you entered is wrong.',
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 2, shadowColor: kPrimary.withOpacity(0.2),
                ),
                child: Text('Confirm', style: ts(15, FontWeight.w700, Colors.white)),
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
    return confirmed;
  }

  void _showChangePinDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF3B82F6), size: 32),
                ),
                const SizedBox(height: 20),
                Text('Change PIN', style: ts(20, FontWeight.w800, kSlate900)),
                const SizedBox(height: 8),
                Text('Update your 4-digit security PIN.',
                    textAlign: TextAlign.center,
                    style: ts(13, FontWeight.w400, kSlate500)),
                const SizedBox(height: 24),
                _StyledPinField(ctrl: currentCtrl, label: 'Current PIN'),
                const SizedBox(height: 14),
                _StyledPinField(ctrl: newCtrl, label: 'New PIN'),
                const SizedBox(height: 14),
                _StyledPinField(ctrl: confirmCtrl, label: 'Confirm New PIN'),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error!, style: ts(12, FontWeight.w600, Colors.red.shade600))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = await AppPrefs.checkPin(currentCtrl.text);
                      if (!ok) { setS(() => error = 'Current PIN is incorrect'); return; }
                      if (newCtrl.text.length != 4) { setS(() => error = 'New PIN must be 4 digits'); return; }
                      if (newCtrl.text != confirmCtrl.text) { setS(() => error = 'PINs do not match'); return; }
                      await AppPrefs.setPin(newCtrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        showResultModal(context,
                          isSuccess: true,
                          title: 'PIN Changed!',
                          message: 'Your security PIN has been updated.',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 2, shadowColor: kPrimary.withOpacity(0.2),
                    ),
                    child: Text('Update PIN', style: ts(15, FontWeight.w700, Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
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
        ),
      ),
    );
  }

  void _showEditSchoolName() {
    final ctrl = TextEditingController(text: _schoolName);
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
                color: kPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, color: kPrimary, size: 32),
            ),
            const SizedBox(height: 20),
            Text('School Name', style: ts(20, FontWeight.w800, kSlate900)),
            const SizedBox(height: 8),
            Text('Update your school\'s display name.',
                textAlign: TextAlign.center,
                style: ts(13, FontWeight.w400, kSlate500)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              style: ts(14, FontWeight.w600, kSlate900),
              decoration: InputDecoration(
                hintText: 'Enter school name',
                hintStyle: ts(14, FontWeight.w400, kSlate400),
                prefixIcon: const Icon(Icons.edit_rounded, color: kSlate400),
                filled: true, fillColor: kSlate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  await AppPrefs.setSchoolName(ctrl.text.trim());
                  setState(() => _schoolName = ctrl.text.trim());
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    showResultModal(context,
                      isSuccess: true,
                      title: 'Name Updated!',
                      message: 'School name has been changed to "${ctrl.text.trim()}".',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 2, shadowColor: kPrimary.withOpacity(0.2),
                ),
                child: Text('Save', style: ts(15, FontWeight.w700, Colors.white)),
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

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final path = await DB.exportToDownloads();
      if (mounted) {
        setState(() => _exporting = false);
        // Share the file so user can send it anywhere
        await Share.shareXFiles([XFile(path)],
            text: 'CheckPay backup – transfer to new phone and use Import Data to restore.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        showResultModal(context,
          isSuccess: false,
          title: 'Export Failed',
          message: 'Could not export data. Please try again.',
        );
      }
    }
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
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
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Import Data', style: ts(20, FontWeight.w800, kSlate900)),
            const SizedBox(height: 12),
            Text(
              'This will REPLACE all current data with the backup file. This cannot be undone.',
              textAlign: TextAlign.center,
              style: ts(13, FontWeight.w400, kSlate500, height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 2, shadowColor: Colors.orange.withOpacity(0.2),
                ),
                child: Text('Continue', style: ts(15, FontWeight.w700, Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
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
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      const typeGroup = XTypeGroup(label: 'Database', extensions: ['db']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) { setState(() => _importing = false); return; }
      await DB.importFrom(file.path);
      if (mounted) {
        setState(() => _importing = false);
        showResultModal(context,
          isSuccess: true,
          title: 'Data Imported!',
          message: 'All data has been restored from the backup.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        showResultModal(context,
          isSuccess: false,
          title: 'Import Failed',
          message: 'Could not import data. Please try again.',
        );
      }
    }
  }

  void _confirmLogout() {
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
              child: Icon(Icons.lock_outline_rounded, color: Colors.red.shade600, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Lock App', style: ts(20, FontWeight.w800, kSlate900)),
            const SizedBox(height: 8),
            Text('Return to the PIN screen?',
                textAlign: TextAlign.center,
                style: ts(13, FontWeight.w400, kSlate500)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 2, shadowColor: Colors.red.withOpacity(0.2),
                ),
                child: Text('Lock Now', style: ts(15, FontWeight.w700, Colors.white)),
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

  void _showAboutUs() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _AboutUsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SingleChildScrollView(
        child: Column(children: [
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
                      color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Settings', style: ts(22, FontWeight.w800, Colors.white)),
                    Text('App preferences & security',
                        style: ts(12, FontWeight.w500, Colors.white.withOpacity(0.75))),
                  ]),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          const _SectionLabel('SCHOOL'),
          _SettingsTile(
            icon: Icons.school_outlined, iconColor: kPrimary,
            title: 'School Name', subtitle: _schoolName,
            onTap: _showEditSchoolName,
            trailing: const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ),
          _SettingsTile(
            icon: Icons.attach_money_rounded, iconColor: kPrimary,
            title: 'School Fees by Class', subtitle: 'Manage tuition rates',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            trailing: const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ),

          const SizedBox(height: 20),

          const _SectionLabel('SECURITY'),
          _SettingsTile(
            icon: Icons.pin_outlined, iconColor: const Color(0xFF3B82F6),
            title: 'Change PIN', subtitle: 'Update your 4-digit PIN',
            onTap: _showChangePinDialog,
            trailing: const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ),
          _SettingsTile(
            icon: Icons.fingerprint_rounded,
            iconColor: _biometricAvailable ? const Color(0xFF8B5CF6) : kSlate400,
            title: 'Biometric Login',
            subtitle: _biometricAvailable ? 'Use fingerprint or face to unlock' : 'Not available on this device',
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: _biometricAvailable ? _toggleBiometric : null,
              activeThumbColor: kPrimary,
            ),
          ),

          const SizedBox(height: 20),

          // ── Data Transfer ──────────────────────────────────
          const _SectionLabel('DATA & BACKUP'),
          _SettingsTile(
            icon: Icons.upload_rounded, iconColor: const Color(0xFF3B82F6),
            title: 'Export Data',
            subtitle: 'Save & share backup to transfer to new phone',
            onTap: _exporting ? null : _exportData,
            trailing: _exporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                : const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ),
          _SettingsTile(
            icon: Icons.download_rounded, iconColor: const Color(0xFFF59E0B),
            title: 'Import Data',
            subtitle: 'Restore from a backup file',
            onTap: _importing ? null : _importData,
            trailing: _importing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                : const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ),

          const SizedBox(height: 20),

          const _SectionLabel('ABOUT'),
          _SettingsTile(
            icon: Icons.info_outline_rounded, iconColor: const Color(0xFF8B5CF6),
            title: 'About Us', subtitle: 'Learn about FrontalMinds',
            onTap: _showAboutUs,
            trailing: const Icon(Icons.chevron_right_rounded, color: kSlate400),
          ),
          const _SettingsTile(
            icon: Icons.code_rounded, iconColor: kSlate500,
            title: 'App Version', subtitle: '1.0.0',
            trailing: SizedBox.shrink(),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: Icon(Icons.lock_outline_rounded, color: Colors.red.shade600),
              label: Text('Lock App', style: ts(15, FontWeight.w700, Colors.red.shade600)),
            ),
          ),
        ]),
          ),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// About Us Screen
// ────────────────────────────────────────────────────────────────────────────
class _AboutUsScreen extends StatelessWidget {
  const _AboutUsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryDark, kPrimary, kPrimaryLight],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(children: [
                Row(children: [
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
                  Text('About Us', style: ts(20, FontWeight.w800, Colors.white)),
                ]),
                const SizedBox(height: 24),
                // Logo circle
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Center(
                    child: Text('FM', style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      color: kPrimary, letterSpacing: -1,
                    )),
                  ),
                ),
                const SizedBox(height: 16),
                Text('FrontalMinds', style: ts(24, FontWeight.w800, Colors.white)),
                const SizedBox(height: 4),
                Text('Powering Intelligence and Driving Innovation', style: ts(13, FontWeight.w500, Colors.white70)),
              ]),
            ),
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AboutCard(
                icon: Icons.lightbulb_outline_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Who We Are',
                content: 'FrontalMinds is a forward-thinking technology company dedicated to building smart, intuitive software solutions for education and beyond. We believe in putting innovation at the forefront of everything we do.',
              ),
              const SizedBox(height: 16),
              _AboutCard(
                icon: Icons.rocket_launch_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: 'Our Mission',
                content: 'Our mission is to simplify school management through elegant and powerful mobile applications. We create tools that save time, reduce errors, and help educators focus on what matters most — teaching.',
              ),
              const SizedBox(height: 16),
              _AboutCard(
                icon: Icons.phone_android_rounded,
                iconColor: kPrimary,
                title: 'CheckPay',
                content: 'CheckPay is our flagship school fee management app. Designed for simplicity and speed, it lets administrators track student payments, generate reports, and manage class records — all from a single, beautiful interface.',
              ),
              const SizedBox(height: 16),
              _AboutCard(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Our Values',
                content: '• Simplicity — Software should be easy and delightful to use\n• Reliability — Your data is safe and always accessible\n• Innovation — We continuously improve and evolve\n• Education — We are passionate about supporting schools',
              ),
              const SizedBox(height: 16),
              _AboutCard(
                icon: Icons.email_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Contact Us',
                content: 'Have questions, feedback, or partnership inquiries? We\'d love to hear from you.\n\n +2348104827838 \n📧 info@frontalminds.com.ng\n🌐 www.frontalminds.com.ng',
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(children: [
                  Text('Made with ❤️ by FrontalMinds', style: ts(12, FontWeight.w500, kSlate400)),
                  const SizedBox(height: 4),
                  Text('© ${DateTime.now().year} FrontalMinds. All rights reserved.',
                      style: ts(11, FontWeight.w400, kSlate400)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;
  const _AboutCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Text(title, style: ts(16, FontWeight.w800, kSlate900)),
        ]),
        const SizedBox(height: 14),
        Text(content, style: ts(13, FontWeight.w400, kSlate500, height: 1.7)),
      ]),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared Widgets
// ────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(label, style: ts(11, FontWeight.w700, kSlate400, letterSpacing: 1.2)),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget trailing;
  const _SettingsTile({required this.icon, required this.iconColor, required this.title,
    required this.subtitle, this.onTap, required this.trailing});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ts(14, FontWeight.w700, kSlate900)),
          const SizedBox(height: 2),
          Text(subtitle, style: ts(12, FontWeight.w400, kSlate500)),
        ])),
        trailing,
      ]),
    ),
  );
}

class _StyledPinField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _StyledPinField({required this.ctrl, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: ts(11, FontWeight.w600, kSlate500)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, obscureText: true,
        keyboardType: TextInputType.number, maxLength: 4,
        style: ts(16, FontWeight.w700, kSlate900),
        decoration: InputDecoration(
          hintText: '• • • •',
          hintStyle: ts(16, FontWeight.w400, kSlate400),
          counterText: '',
          filled: true, fillColor: kSlate100,
          prefixIcon: const Icon(Icons.lock_rounded, color: kSlate400, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ],
  );
}
