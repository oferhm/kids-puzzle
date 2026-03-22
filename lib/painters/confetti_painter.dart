import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;       // 0..1 (fraction of width)
  double y;       // 0..1 (fraction of height)
  double vy;      // fall speed
  double vx;      // horizontal drift
  double rotation;
  double rotSpeed;
  double width;
  double height;
  Color  color;
  int    shape;   // 0=rect, 1=circle, 2=ribbon

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vy,
    required this.vx,
    required this.rotation,
    required this.rotSpeed,
    required this.width,
    required this.height,
    required this.color,
    required this.shape,
  });
}

/// Full-screen confetti rain over the solved puzzle.
/// Call [update] each frame with elapsed seconds.
class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double opacity;

  const ConfettiPainter({required this.particles, required this.opacity});

  static List<ConfettiParticle> createParticles({int count = 120, int? seed}) {
    final rng = Random(seed);
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFFF4757),
      const Color(0xFF2ED573),
      const Color(0xFF1E90FF),
      const Color(0xFFFF6B81),
      const Color(0xFFFFA502),
      const Color(0xFF7BED9F),
      const Color(0xFFECCC68),
      const Color(0xFFA29BFE),
      const Color(0xFFFF7F50),
    ];
    return List.generate(count, (i) => ConfettiParticle(
      x:        rng.nextDouble(),
      y:        -rng.nextDouble() * 2.0,       // stagger start above screen
      vy:       0.002 + rng.nextDouble() * 0.004,
      vx:       (rng.nextDouble() - 0.5) * 0.0015,
      rotation: rng.nextDouble() * 2 * pi,
      rotSpeed: (rng.nextDouble() - 0.5) * 0.20,
      width:    8  + rng.nextDouble() * 14,
      height:   5  + rng.nextDouble() * 9,
      color:    colors[rng.nextInt(colors.length)],
      shape:    rng.nextInt(3),
    ));
  }

  /// Update particle positions. Call in an AnimationController listener.
  static void update(List<ConfettiParticle> particles, double dtSeconds) {
    for (final p in particles) {
      p.y        += p.vy * dtSeconds * 60;
      p.x        += p.vx * dtSeconds * 60;
      p.rotation += p.rotSpeed;
      // Add gentle sine wobble
      p.x += sin(p.y * 8) * 0.0005;
      // Wrap around when below screen
      if (p.y > 1.1) {
        p.y  = -0.05;
        p.x  = Random().nextDouble();
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity.clamp(0, 1))
        ..style = PaintingStyle.fill;

      switch (p.shape) {
        case 0: // rectangle
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
            paint,
          );
          break;
        case 1: // circle
          canvas.drawCircle(Offset.zero, p.height * 0.6, paint);
          break;
        case 2: // ribbon / thin strip
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: p.width * 1.5, height: p.height * 0.5),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => true;
}