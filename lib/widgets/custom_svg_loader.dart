import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomSvgLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const CustomSvgLoader({super.key, this.size = 48, this.color});

  @override
  State<CustomSvgLoader> createState() => _CustomSvgLoaderState();
}

class _CustomSvgLoaderState extends State<CustomSvgLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1.5 second rotation and pulse loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Creates a pulsing triangle wave for opacity (0.4 to 1.0)
          final pulse = 0.4 + 0.6 * (1 - (_controller.value * 2 - 1).abs());
          return Transform.rotate(
            angle: _controller.value * 2.0 * 3.14159, // Full 360 degree rotation
            child: Opacity(
              opacity: pulse,
              child: child,
            ),
          );
        },
        child: SvgPicture.asset(
          'assets/icons/nav_scan_qr.svg', // A cool techy icon from your assets
          width: widget.size,
          height: widget.size,
          colorFilter: ColorFilter.mode(widget.color ?? Colors.blue.shade700, BlendMode.srcIn),
        ),
      ),
    );
  }
}
