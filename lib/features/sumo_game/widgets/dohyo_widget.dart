import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class DohyoWidget extends StatelessWidget {
  final double position; // -1.0 to 1.0, 0 = center
  final bool gameOver;
  final bool playerWon;

  const DohyoWidget({
    super.key,
    required this.position,
    required this.gameOver,
    required this.playerWon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final radius = size / 2;
        final sumoSize = size * 0.15;

        // Clamp position for display
        final clampedPos = position.clamp(-1.2, 1.2);

        // Player is on the left side, rival on the right
        // Position affects both: positive = player pushing right (winning)
        final centerY = radius;
        final centerX = radius;

        // Sumo positions along horizontal axis
        final playerX = centerX - sumoSize + (clampedPos * radius * 0.6);
        final rivalX = centerX + sumoSize * 0.2 + (clampedPos * radius * 0.6);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // Dohyo circle (ring)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DohyoPainter(),
                ),
              ),
              // Player sumo (left, blue)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                left: playerX - sumoSize / 2,
                top: centerY - sumoSize / 2,
                child: _SumoFighter(
                  size: sumoSize,
                  color: AppColors.algorithm,
                  label: 'TU',
                  facingRight: true,
                ),
              ),
              // Rival sumo (right, red)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                left: rivalX - sumoSize / 2,
                top: centerY - sumoSize / 2,
                child: _SumoFighter(
                  size: sumoSize,
                  color: AppColors.sumoGame,
                  label: 'RIVAL',
                  facingRight: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SumoFighter extends StatelessWidget {
  final double size;
  final Color color;
  final String label;
  final bool facingRight;

  const _SumoFighter({
    required this.size,
    required this.color,
    required this.label,
    required this.facingRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              facingRight ? '>' : '<',
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DohyoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center + const Offset(0, 4), radius, shadowPaint);

    // Dohyo ground (sand color)
    final groundPaint = Paint()
      ..color = const Color(0xFFF5E6D3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, groundPaint);

    // Inner ring
    final innerPaint = Paint()
      ..color = const Color(0xFFE0C9A8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.85, innerPaint);

    // Ring border (tawara)
    final ringPaint = Paint()
      ..color = const Color(0xFF8B7355)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06;
    canvas.drawCircle(center, radius * 0.85, ringPaint);

    // Center line
    final linePaint = Paint()
      ..color = const Color(0xFFC4A882)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.15),
      Offset(center.dx, center.dy + radius * 0.15),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
