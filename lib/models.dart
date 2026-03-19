class SchoolClass {
  final int id;
  final String name;
  final String section;
  final int studentCount;
  final double paymentProgress;
  final double feeAmount;

  const SchoolClass({
    required this.id,
    required this.name,
    required this.section,
    required this.studentCount,
    required this.paymentProgress,
    required this.feeAmount,
  });
}

class Student {
  final String id;
  final String name;
  final String className;
  final String? photoPath;
  final String? parentName;
  final String? phone;
  bool isPaid;

  Student({
    required this.id,
    required this.name,
    required this.className,
    this.photoPath,
    this.parentName,
    this.phone,
    this.isPaid = false,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return parts[0].substring(0, 2).toUpperCase();
  }
}

class PaymentRecord {
  final String month;
  final int year;
  final bool paid;
  final String? date;

  const PaymentRecord({
    required this.month,
    required this.year,
    required this.paid,
    this.date,
  });
}
