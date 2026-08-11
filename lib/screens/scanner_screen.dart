import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Enum for the scan result state
enum ScanState { scanning, success, error }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  ScanState _scanState = ScanState.scanning;

  // Animation controllers
  late AnimationController _resultAnimController;
  late AnimationController _scanLineController;
  late Animation<double> _circleScaleAnim;
  late Animation<double> _iconDrawAnim;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();

    // Controller for the success/error result animation
    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _circleScaleAnim = CurvedAnimation(
      parent: _resultAnimController,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _iconDrawAnim = CurvedAnimation(
      parent: _resultAnimController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    // Scanning line animation
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _resultAnimController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _onScanSuccess(String poleId) {
    if (_scanState != ScanState.scanning) return;
    setState(() => _scanState = ScanState.success);
    _scanLineController.stop();
    _resultAnimController.forward();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pop(context, poleId);
    });
  }

  void _onScanError() {
    if (_scanState != ScanState.scanning) return;
    setState(() => _scanState = ScanState.error);
    _scanLineController.stop();
    _resultAnimController.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _resultAnimController.reset();
        _scanLineController.repeat(reverse: true);
        setState(() => _scanState = ScanState.scanning);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_scanState != ScanState.scanning) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final rawValue = barcodes.first.rawValue;
                if (rawValue != null && rawValue.startsWith('QRSYS_POLE_')) {
                  final poleId = rawValue.replaceFirst('QRSYS_POLE_', '');
                  _onScanSuccess(poleId);
                } else if (rawValue != null) {
                  _onScanError();
                }
              }
            },
          ),

          // Dark overlay with a square cutout
          _buildOverlay(context),

          // Top back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    const frameSize = 250.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final frameTop = (screenHeight - frameSize) / 2 - 40;

    return Stack(
      children: [
        // Top dark panel
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: frameTop,
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),
        // Left dark panel
        Positioned(
          top: frameTop,
          left: 0,
          width: (screenWidth - frameSize) / 2,
          height: frameSize,
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),
        // Right dark panel
        Positioned(
          top: frameTop,
          right: 0,
          width: (screenWidth - frameSize) / 2,
          height: frameSize,
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),
        // Bottom dark panel
        Positioned(
          top: frameTop + frameSize,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),

        // The animated scanning frame
        Positioned(
          top: frameTop,
          left: (screenWidth - frameSize) / 2,
          child: _buildScanFrame(frameSize),
        ),

        // Status text below the frame
        Positioned(
          top: frameTop + frameSize + 30,
          left: 0,
          right: 0,
          child: _buildStatusText(),
        ),
      ],
    );
  }

  Widget _buildScanFrame(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Scanning line (only shown when scanning)
          if (_scanState == ScanState.scanning)
            AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, __) {
                return Positioned(
                  top: _scanLineAnim.value * (size - 4),
                  left: 4,
                  right: 4,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.blue.shade400.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),

          // Corner brackets
          CustomPaint(
            size: Size(size, size),
            painter: _CornerBracketPainter(
              color: _scanState == ScanState.success
                  ? Colors.green
                  : _scanState == ScanState.error
                      ? Colors.red
                      : Colors.white,
            ),
          ),

          // Success/Error animated icon overlay
          if (_scanState != ScanState.scanning)
            Center(
              child: AnimatedBuilder(
                animation: _resultAnimController,
                builder: (_, __) {
                  final isSuccess = _scanState == ScanState.success;
                  final color = isSuccess ? Colors.green : Colors.red;

                  return Transform.scale(
                    scale: _circleScaleAnim.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.15),
                        border: Border.all(color: color, width: 3),
                      ),
                      child: CustomPaint(
                        painter: isSuccess
                            ? _CheckmarkPainter(
                                progress: _iconDrawAnim.value,
                                color: color,
                              )
                            : _XMarkPainter(
                                progress: _iconDrawAnim.value,
                                color: color,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    Color color;

    switch (_scanState) {
      case ScanState.success:
        text = 'QR Code Recognized!';
        color = Colors.green;
        break;
      case ScanState.error:
        text = 'Invalid QR Code';
        color = Colors.red;
        break;
      case ScanState.scanning:
        text = 'Align QR code within the frame';
        color = Colors.white70;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// Draws the 4 corner L-bracket lines of the scanner frame
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const length = 28.0;
    const r = 8.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, length)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(length, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width - r, 0)
        ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
        ..lineTo(size.width, length),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - length)
        ..lineTo(0, size.height - r)
        ..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r))
        ..lineTo(length, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, size.height)
        ..lineTo(size.width - r, size.height)
        ..arcToPoint(Offset(size.width, size.height - r),
            radius: const Radius.circular(r))
        ..lineTo(size.width, size.height - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Draws an animated checkmark stroke
class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Checkmark path: two segments
    // Segment 1: (0.2, 0.5) -> (0.43, 0.72)   40% of total length
    // Segment 2: (0.43, 0.72) -> (0.78, 0.32)  60% of total length
    final p1 = Offset(size.width * 0.22, size.height * 0.50);
    final p2 = Offset(size.width * 0.43, size.height * 0.70);
    final p3 = Offset(size.width * 0.78, size.height * 0.30);

    const seg1Length = 0.4;
    const seg2Length = 0.6;

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (progress <= seg1Length) {
      final t = progress / seg1Length;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (progress - seg1Length) / seg2Length;
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      old.progress != progress || old.color != color;
}

// Draws an animated X stroke
class _XMarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  _XMarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const arm = 22.0;
    const angle = pi / 4;

    // Line 1: top-left to bottom-right
    final line1Start = Offset(cx - arm * cos(angle), cy - arm * sin(angle));
    final line1End = Offset(cx + arm * cos(angle), cy + arm * sin(angle));

    // Line 2: top-right to bottom-left
    final line2Start = Offset(cx + arm * cos(angle), cy - arm * sin(angle));
    final line2End = Offset(cx - arm * cos(angle), cy + arm * sin(angle));

    // Draw line1 in first half, line2 in second half
    if (progress <= 0.5) {
      final t = progress / 0.5;
      canvas.drawLine(
        line1Start,
        Offset(
          line1Start.dx + (line1End.dx - line1Start.dx) * t,
          line1Start.dy + (line1End.dy - line1Start.dy) * t,
        ),
        paint,
      );
    } else {
      canvas.drawLine(line1Start, line1End, paint);
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(
        line2Start,
        Offset(
          line2Start.dx + (line2End.dx - line2Start.dx) * t,
          line2Start.dy + (line2End.dy - line2Start.dy) * t,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_XMarkPainter old) =>
      old.progress != progress || old.color != color;
}
