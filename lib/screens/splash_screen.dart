import 'package:flutter/material.dart';
import 'mpin_lock_screen.dart';
import 'login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showHome = false;
  bool _imagePrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagePrecached) {
      precacheImage(const AssetImage('assets/banner.png'), context);
      _imagePrecached = true;
    }
  }

  @override
  void initState() {
    super.initState();
    // Start spinning animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Show Home after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showHome = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 1200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // A smooth Fade and slight Slide
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.05), // slightly from bottom
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _showHome 
            ? (Supabase.instance.client.auth.currentSession != null
                ? const MpinLockScreen(key: ValueKey('mpin'))
                : const LoginScreen(key: ValueKey('login')))
            : _buildSplash(),
      ),
    );
  }

  Widget _buildSplash() {
    return Scaffold(
      key: const ValueKey('splash'),
      backgroundColor: Colors.white,
      body: Center(
        child: RotationTransition(
          turns: _controller,
          child: SizedBox(
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: _ColoredSpinnerPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColoredSpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 10.0;
    final Rect rect = const Offset(strokeWidth / 2, strokeWidth / 2) & 
                      Size(size.width - strokeWidth, size.height - strokeWidth);
                      
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Blue arc
    paint.color = Colors.blue.shade700;
    canvas.drawArc(rect, -pi / 2, 2 * pi / 3, false, paint);

    // Red arc
    paint.color = Colors.red.shade600;
    canvas.drawArc(rect, -pi / 2 + (2 * pi / 3), 2 * pi / 3, false, paint);

    // Yellow arc
    paint.color = Colors.amber.shade600;
    canvas.drawArc(rect, -pi / 2 + (4 * pi / 3), 2 * pi / 3, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
