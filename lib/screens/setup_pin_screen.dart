import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/app_prefs.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});
  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final List<String> _pin = [];
  final List<String> _confirm = [];
  bool _confirming = false;
  bool _mismatch = false;

  List<String> get _active => _confirming ? _confirm : _pin;

  void _onKey(String key) {
    if (_active.length >= 4) return;
    setState(() { _active.add(key); _mismatch = false; });
    if (_active.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _advance);
    }
  }

  void _onBackspace() {
    if (_active.isEmpty) return;
    setState(() => _active.removeLast());
  }

  void _advance() {
    if (!_confirming) {
      setState(() => _confirming = true);
    } else {
      if (_pin.join() == _confirm.join()) {
        _save();
      } else {
        setState(() {
          _mismatch = true;
          _confirm.clear();
        });
      }
    }
  }

  Future<void> _save() async {
    await AppPrefs.setPin(_pin.join());
    if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F6),
        body: Stack(children: [
          Positioned(top: -96, left: -96,
              child: _Blob(kPrimary.withOpacity(0.1), 384)),
          Positioned(bottom: -96, right: -96,
              child: _Blob(kPrimary.withOpacity(0.08), 300)),
          SafeArea(child: Column(children: [
            const SizedBox(height: 16),
            Center(child: Text('CheckPay', style: ts(18, FontWeight.w800, kSlate900))),
            const SizedBox(height: 32),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: kPrimary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              _confirming ? 'Confirm Your PIN' : 'Create a PIN',
              style: ts(26, FontWeight.w800, kSlate900),
            ),
            const SizedBox(height: 8),
            Text(
              _confirming
                  ? 'Enter the same PIN again to confirm'
                  : 'Choose a 4-digit PIN to secure the app',
              style: ts(14, FontWeight.w500, kSlate500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_mismatch)
              Text("PINs don't match. Try again.",
                  style: ts(13, FontWeight.w600, Colors.red)),
            const SizedBox(height: 32),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _active.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 48, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _mismatch
                          ? Colors.red.shade300
                          : filled ? kPrimary : Colors.white.withOpacity(0.3),
                      width: filled ? 2 : 1,
                    ),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: filled
                      ? Center(child: Container(width: 12, height: 12,
                          decoration: const BoxDecoration(
                              color: kSlate900, shape: BoxShape.circle)))
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
                      child: _NumKey(label: k, onTap: () => _onKey(k)),
                    ))).toList()),
                  ),
                Row(children: [
                  // Back to re-enter first PIN
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _NumKey(
                      child: const Icon(Icons.refresh_rounded, color: kSlate400, size: 22),
                      onTap: _confirming
                          ? () => setState(() { _confirming = false; _pin.clear(); _confirm.clear(); _mismatch = false; })
                          : () {},
                    ))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _NumKey(label: '0', onTap: () => _onKey('0')))),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _NumKey(
                      child: const Icon(Icons.backspace_outlined, color: kSlate400, size: 24),
                      onTap: _onBackspace,
                    ))),
                ]),
              ]),
            ),
            const Spacer(),
            // Step indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StepDot(active: !_confirming, done: _confirming),
                const SizedBox(width: 8),
                _StepDot(active: _confirming, done: false),
              ]),
            ),
          ])),
        ]),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active, done;
  const _StepDot({required this.active, required this.done});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: active ? 24 : 8, height: 8,
    decoration: BoxDecoration(
      color: (active || done) ? kPrimary : kSlate400.withOpacity(0.3),
      borderRadius: BorderRadius.circular(999),
    ),
  );
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
  const _NumKey({this.label, this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
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
  );
}
