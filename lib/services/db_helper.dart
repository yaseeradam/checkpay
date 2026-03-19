import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models.dart';

class DB {
  static Database? _db;
  static const _version = 2;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'checkpay.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
        await _createTables(db);
        await _seedClasses(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2: no schema change yet, reserved for future use
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE classes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        section TEXT NOT NULL,
        fee_amount REAL NOT NULL DEFAULT 150000
      )
    ''');
    await db.execute('''
      CREATE TABLE students(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        class_name TEXT NOT NULL,
        photo_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        month TEXT NOT NULL,
        year INTEGER NOT NULL,
        paid INTEGER NOT NULL DEFAULT 0,
        date TEXT,
        UNIQUE(student_id, month, year)
      )
    ''');
  }

  static Future<void> _seedClasses(Database db) async {
    final batch = db.batch();
    for (final c in _seeds) {
      batch.insert('classes', {'name': c[0], 'section': c[1], 'fee_amount': c[2]});
    }
    await batch.commit(noResult: true);
  }

  static const _seeds = [
    ['JSS 1', 'Junior Section', 150000.0],
    ['JSS 2', 'Junior Section', 150000.0],
    ['JSS 3', 'Junior Section', 155000.0],
    ['SS 1',  'Senior Section', 180000.0],
    ['SS 2',  'Senior Section', 180000.0],
  ];

  // ── Classes ──────────────────────────────────────────────
  /// Optimised: fetches all students + payments in 2 queries total, not N+1.
  static Future<List<SchoolClass>> getClasses() async {
    try {
      final db = await instance;
      final now = DateTime.now();
      final month = _monthName(now.month);

      final classRows = await db.query('classes', orderBy: 'id ASC');

      // Single query: all paid payments for current month
      final paidRows = await db.rawQuery('''
        SELECT student_id FROM payments
        WHERE month = ? AND year = ? AND paid = 1
      ''', [month, now.year]);
      final paidIds = {for (final r in paidRows) r['student_id'] as String};

      // Single query: all students
      final studentRows = await db.query('students');

      final classes = <SchoolClass>[];
      for (final row in classRows) {
        final name = row['name'] as String;
        final classStudents = studentRows.where((s) => s['class_name'] == name).toList();
        final total = classStudents.length;
        final paid = classStudents.where((s) => paidIds.contains(s['id'])).length;
        classes.add(SchoolClass(
          id: row['id'] as int,
          name: name,
          section: row['section'] as String,
          studentCount: total,
          paymentProgress: total == 0 ? 0 : paid / total,
          feeAmount: (row['fee_amount'] as num).toDouble(),
        ));
      }
      return classes;
    } catch (e) {
      throw Exception('Failed to load classes: $e');
    }
  }

  static Future<int> addClass(String name, String section, double fee) async {
    try {
      final db = await instance;
      return db.insert('classes', {'name': name, 'section': section, 'fee_amount': fee});
    } catch (e) {
      throw Exception('Failed to add class: $e');
    }
  }

  static Future<void> updateClassFee(int id, double fee) async {
    try {
      final db = await instance;
      await db.update('classes', {'fee_amount': fee}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to update fee: $e');
    }
  }

  static Future<void> deleteClass(int id) async {
    try {
      final db = await instance;
      await db.delete('classes', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  // ── Students ─────────────────────────────────────────────
  /// Returns students with isPaid reflecting the given month/year.
  static Future<List<Student>> getStudentsForMonth(
      String className, String month, int year) async {
    try {
      final db = await instance;
      final rows = await db.query('students',
          where: 'class_name = ?', whereArgs: [className], orderBy: 'name ASC');

      // Single query for all payments for this class+month+year
      final ids = rows.map((r) => r['id'] as String).toList();
      if (ids.isEmpty) return [];

      final placeholders = List.filled(ids.length, '?').join(',');
      final paidRows = await db.rawQuery('''
        SELECT student_id FROM payments
        WHERE student_id IN ($placeholders) AND month = ? AND year = ? AND paid = 1
      ''', [...ids, month, year]);
      final paidIds = {for (final r in paidRows) r['student_id'] as String};

      return rows.map((row) => Student(
        id: row['id'] as String,
        name: row['name'] as String,
        className: row['class_name'] as String,
        photoPath: row['photo_path'] as String?,
        isPaid: paidIds.contains(row['id'] as String),
      )).toList();
    } catch (e) {
      throw Exception('Failed to load students: $e');
    }
  }

  /// Convenience: uses current month.
  static Future<List<Student>> getStudents(String className) async {
    final now = DateTime.now();
    return getStudentsForMonth(className, _monthName(now.month), now.year);
  }

  static Future<void> addStudent(Student s) async {
    try {
      final db = await instance;
      // Check for duplicate ID
      final existing = await db.query('students', where: 'id = ?', whereArgs: [s.id]);
      if (existing.isNotEmpty) {
        throw Exception('DUPLICATE_ID');
      }
      await db.insert('students', {
        'id': s.id,
        'name': s.name,
        'class_name': s.className,
        'photo_path': s.photoPath,
      });
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteStudent(String id) async {
    try {
      final db = await instance;
      await db.delete('students', where: 'id = ?', whereArgs: [id]);
      await db.delete('payments', where: 'student_id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete student: $e');
    }
  }

  // ── Payments ─────────────────────────────────────────────
  static Future<void> setPayment(
      String studentId, String month, int year, bool paid) async {
    try {
      final db = await instance;
      final date = paid ? DateTime.now().toString().substring(0, 10) : null;
      await db.insert('payments', {
        'student_id': studentId,
        'month': month,
        'year': year,
        'paid': paid ? 1 : 0,
        'date': date,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      throw Exception('Failed to save payment: $e');
    }
  }

  static Future<List<PaymentRecord>> getPaymentHistory(String studentId) async {
    try {
      final db = await instance;
      final rows = await db.query('payments',
          where: 'student_id = ?',
          whereArgs: [studentId],
          orderBy: 'year DESC, id DESC');
      return rows.map((r) => PaymentRecord(
        month: r['month'] as String,
        year: r['year'] as int,
        paid: (r['paid'] as int) == 1,
        date: r['date'] as String?,
      )).toList();
    } catch (e) {
      throw Exception('Failed to load payment history: $e');
    }
  }

  /// Optimised: fetches all payments for last 6 months in ONE query.
  static Future<Map<String, int>> getMonthlyPaidCounts(
      List<String> months, int year) async {
    try {
      final db = await instance;
      final placeholders = List.filled(months.length, '?').join(',');
      final rows = await db.rawQuery('''
        SELECT month, COUNT(*) as cnt FROM payments
        WHERE month IN ($placeholders) AND year = ? AND paid = 1
        GROUP BY month
      ''', [...months, year]);
      return {for (final r in rows) r['month'] as String: r['cnt'] as int};
    } catch (e) {
      return {};
    }
  }

  // ── Backup / Restore ─────────────────────────────────────
  static Future<String> getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'checkpay.db');
  }

  static Future<String> exportToDownloads() async {
    try {
      final src = await getDbPath();
      // Use app documents dir — safe on all Android versions, then share via share sheet
      final dir = await getApplicationDocumentsDirectory();
      final destPath = p.join(dir.path, 'checkpay_backup.db');
      await File(src).copy(destPath);
      return destPath;
    } catch (e) {
      throw Exception('Export failed: $e');
    }
  }

  static Future<void> importFrom(String filePath) async {
    try {
      final dest = await getDbPath();
      _db = null;
      await File(filePath).copy(dest);
      _db = await _open();
    } catch (e) {
      throw Exception('Import failed: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  static String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }
}
