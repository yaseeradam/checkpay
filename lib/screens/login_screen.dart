import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../theme.dart';
import '../services/app_prefs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<String> _pin = [];
  bool _error = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  final _auth = LocalAuthentication();

  // Lockout
  int _failedAttempts = 0;
  int _lockoutSecondsLeft = 0;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final bio = await AppPrefs.getBiometric();
    final failed = await AppPrefs.getFailedAttempts();
    final remainingMs = await AppPrefs.lockoutRemainingMs();
    bool canCheck = false;
    try {
      canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (canCheck) {
        final available = await _auth.getAvailableBiometrics();
        canCheck = available.isNotEmpty;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _biometricEnabled = bio;
        _biometricAvailable = canCheck;
        _failedAttempts = failed;
        if (remainingMs > 0) _startLockCountdown(remainingMs);
      });
    }
    if (bio && canCheck && remainingMs == 0) _tryBiometric();
  }

  void _startLockCountdown(int remainingMs) {
    _lockoutSecondsLeft = (remainingMs / 1000).ceil();
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _lockoutSecondsLeft--;
        if (_lockoutSecondsLeft <= 0) {
          _lockoutSecondsLeft = 0;
          t.cancel();
        }
      });
    });
  }

  Future<void> _tryBiometric() async {
    try {
      // Check if any biometrics are available
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) return;

      // Get list of available biometric types
      final availableBiometrics = await _auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return;

      final authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access CheckPay',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      if (authenticated && mounted) {
        await AppPrefs.resetFailedAttempts();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on PlatformException catch (_) {
      // Biometric auth failed or not available — user can still use PIN
    } catch (_) {}
  }

  void _onKey(String key) {
    if (_lockoutSecondsLeft > 0) return;
    if (_pin.length >= 4) return;
    setState(() { _pin.add(key); _error = false; });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _verify);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _verify() async {
    final correct = await AppPrefs.checkPin(_pin.join());
    if (!mounted) return;
    if (correct) {
      await AppPrefs.resetFailedAttempts();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      await AppPrefs.incrementFailedAttempts();
      final failed = await AppPrefs.getFailedAttempts();
      final remainingMs = await AppPrefs.lockoutRemainingMs();
      if (!mounted) return;
      setState(() {
        _error = true;
        _pin.clear();
        _failedAttempts = failed;
        if (remainingMs > 0) _startLockCountdown(remainingMs);
      });
    }
  }

  bool get _isLocked => _lockoutSecondsLeft > 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // disable back button
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F6),
        body: Stack(children: [
          Positioned(top: -96, left: -96, child: _Blob(kPrimary.withOpacity(0.1), 384)),
          Positioned(top: MediaQuery.of(context).size.height * 0.5, right: -96,
              child: _Blob(kPrimary.withOpacity(0.05), 320)),
          Positioned(bottom: -96, left: MediaQuery.of(context).size.width * 0.25,
              child: _Blob(kPrimary.withOpacity(0.1), 256)),
          SafeArea(child: Column(children: [
            const SizedBox(height: 16),
            // No back button — just centered title
            Center(child: Text('CheckPay',
                style: ts(18, FontWeight.w800, kSlate900))),
            const SizedBox(height: 24),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.lock_rounded, color: kPrimary, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Welcome Back', style: ts(28, FontWeight.w800, kSlate900)),
            const SizedBox(height: 8),
            Text('Enter your secure PIN', style: ts(14, FontWeight.w500, kSlate500)),
            const SizedBox(height: 8),
            if (_isLocked)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 6),
                  Text('Too many attempts. Try in ${_lockoutSecondsLeft}s',
                      style: ts(13, FontWeight.w600, Colors.orange.shade700)),
                ]),
              )
            else if (_error)
              Text(
                _failedAttempts >= 4
                    ? 'Incorrect PIN. ${5 - _failedAttempts % 5} attempt(s) left.'
                    : 'Incorrect PIN. Try again.',
                style: ts(13, FontWeight.w600, Colors.red),
              ),
            const SizedBox(height: 32),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 48, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isLocked
                          ? Colors.orange.shade300
                          : _error
                              ? Colors.red.shade300
                              : filled ? kPrimary : Colors.white.withOpacity(0.3),
                      width: filled ? 2 : 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: filled
                      ? Center(child: Container(width: 12, height: 12,
                          decoration: const BoxDecoration(color: kSlate900, shape: BoxShape.circle)))
                      : null,
                );
              }),
            ),
            const SizedBox(height: 40),
            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(children: [
                for (final row in [['1','2','3'],['4','5','6'],['7','8','9']])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(children: row.map((k) => Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _NumKey(label: k, onTap: () => _onKey(k), disabled: _isLocked),
                    ))).toList()),
                  ),
                Row(children: [
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: (_biometricEnabled && _biometricAvailable)
                      ? _NumKey(
                          child: Icon(Icons.fingerprint_rounded,
                              color: !_isLocked ? kPrimary : kSlate400, size: 28),
                          onTap: !_isLocked ? _tryBiometric : () {},
                          disabled: _isLocked,
                        )
                      : const SizedBox(height: 64),
                  )),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _NumKey(label: '0', onTap: () => _onKey('0'), disabled: _isLocked))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _NumKey(
                      child: const Icon(Icons.backspace_outlined, color: kSlate400, size: 24),
                      onTap: _onBackspace, disabled: false,
                    ))),
                ]),
              ]),
            ),
            const Spacer(),
            // Biometric hint text at bottom instead of unlock button
            if (_biometricEnabled && _biometricAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: GestureDetector(
                  onTap: (!_isLocked) ? _tryBiometric : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, color: kPrimary.withOpacity(0.6), size: 18),
                      const SizedBox(width: 6),
                      Text('Tap to use biometric login',
                          style: ts(13, FontWeight.w500, kSlate500)),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 32),
          ])),
        ]),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color; final double size;
  const _Blob(this.color, this.size);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _NumKey extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback onTap;
  final bool disabled;
  const _NumKey({this.label, this.child, required this.onTap, this.disabled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled ? null : onTap,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: disabled ? 0.4 : 1.0,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Center(child: label != null
            ? Text(label!, style: ts(22, FontWeight.w600, kSlate900))
            : child),
      ),
    ),
  );
}
