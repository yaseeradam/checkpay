import 'package:flutter/material.dart';
import '../theme.dart';

/// Shows a beautiful success or error modal dialog.
/// Auto-dismisses after [autoDismissSeconds] if provided.
Future<void> showResultModal(
  BuildContext context, {
  required bool isSuccess,
  required String title,
  String? message,
  int autoDismissSeconds = 2,
}) async {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, a1, a2, child) {
      final curve = CurvedAnimation(parent: a1, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: curve,
        child: FadeTransition(
          opacity: a1,
          child: _ResultModalContent(
            isSuccess: isSuccess,
            title: title,
            message: message,
          ),
        ),
      );
    },
  );

  if (autoDismissSeconds > 0) {
    await Future.delayed(Duration(seconds: autoDismissSeconds));
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _ResultModalContent extends StatefulWidget {
  final bool isSuccess;
  final String title;
  final String? message;

  const _ResultModalContent({
    required this.isSuccess,
    required this.title,
    this.message,
  });

  @override
  State<_ResultModalContent> createState() => _ResultModalContentState();
}

class _ResultModalContentState extends State<_ResultModalContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _iconCtrl.forward();
    });
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSuccess ? const Color(0xFF21C45E) : const Color(0xFFEF4444);
    final bgColor = widget.isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final icon = widget.isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Center(
      child: Container(
        width: 300,
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _iconScale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 44),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: ts(20, FontWeight.w800, kSlate900),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: ts(13, FontWeight.w500, kSlate500, height: 1.5),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
