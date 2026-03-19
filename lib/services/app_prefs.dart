import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const _keyPin           = 'app_pin_hash';
  static const _keyBiometric     = 'biometric_enabled';
  static const _keySchoolName    = 'school_name';
  static const _keyPinSet        = 'pin_is_set';
  static const _keyFailedAttempts = 'failed_attempts';
  static const _keyLockUntil     = 'lock_until_ms';
  static const _keyLogoPath      = 'school_logo_path';

  // ── PIN hashing ───────────────────────────────────────────
  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  // ── First launch ──────────────────────────────────────────
  static Future<bool> isPinSet() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyPinSet) ?? false;
  }

  // ── PIN ───────────────────────────────────────────────────
  static Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPin, _hash(pin));
    await p.setBool(_keyPinSet, true);
    await p.setInt(_keyFailedAttempts, 0); // reset on new PIN
  }

  static Future<bool> checkPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_keyPin);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  // ── Brute-force protection ────────────────────────────────
  static Future<int> getFailedAttempts() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyFailedAttempts) ?? 0;
  }

  static Future<void> incrementFailedAttempts() async {
    final p = await SharedPreferences.getInstance();
    final current = p.getInt(_keyFailedAttempts) ?? 0;
    await p.setInt(_keyFailedAttempts, current + 1);
    // Lock for 30 seconds after every 5 failures
    if ((current + 1) % 5 == 0) {
      final lockUntil = DateTime.now().millisecondsSinceEpoch + 30000;
      await p.setInt(_keyLockUntil, lockUntil);
    }
  }

  static Future<void> resetFailedAttempts() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyFailedAttempts, 0);
    await p.remove(_keyLockUntil);
  }

  /// Returns milliseconds remaining in lockout, or 0 if not locked.
  static Future<int> lockoutRemainingMs() async {
    final p = await SharedPreferences.getInstance();
    final lockUntil = p.getInt(_keyLockUntil) ?? 0;
    final remaining = lockUntil - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  // ── Biometric ─────────────────────────────────────────────
  static Future<bool> getBiometric() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyBiometric) ?? false;
  }

  static Future<void> setBiometric(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyBiometric, value);
  }

  // ── School name ───────────────────────────────────────────
  static Future<String> getSchoolName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keySchoolName) ?? 'My School';
  }

  static Future<void> setSchoolName(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keySchoolName, name);
  }

  // ── School logo ───────────────────────────────────────────
  static Future<String?> getLogoPath() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyLogoPath);
  }

  static Future<void> setLogoPath(String? path) async {
    final p = await SharedPreferences.getInstance();
    if (path == null) {
      await p.remove(_keyLogoPath);
    } else {
      await p.setString(_keyLogoPath, path);
    }
  }
}
