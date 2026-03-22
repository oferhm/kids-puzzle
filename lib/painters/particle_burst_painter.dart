import 'dart:math';
import 'package:flutter/material.dart';

class _Particle {
  Offset pos;
  Offset vel;
  Color  color;
  double radius;
  double opacity;
  int    shape; // 0=circle, 1=diamond, 2=star

  _Particle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.radius,
    required this.opacity,
    required this.shape,
  });
}

/// Paints an animated burst of particles radiating from [center].
/// Drive with an AnimationController from 0.0 → 1.0.
class ParticleBurstPainter extends CustomPainter {
  final double progress;
  final Offset center;
  final List<_Particle> _particles;

  ParticleBurstPainter._({
    required this.progress,
    required this.center,
    required List<_Particle> particles,
  }) : _particles = particles;

  static ParticleBurstPainter create({
    required double progress,
    required Offset center,
    required double radius,
    int count = 30,
    int? seed,
  }) {
    final rng = Random(seed ?? center.dx.toInt() ^ center.dy.toInt());
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFFF4444),
      const Color(0xFF00CEC9),
      const Color(0xFF6C5CE7),
      const Color(0xFFFF8B94),
      const Color(0xFFFFAA5C),
      const Color(0xFF00B894),
      const Color(0xFF0984E3),
      const Color(0xFFFF7675),
      const Color(0xFFFDCB6E),
    ];

    final particles = List.generate(count, (i) {
      final angle = (i / count) * 2 * pi + rng.nextDouble() * 0.5;
      final speed = radius * (0.7 + rng.nextDouble() * 0.6);
      return _Particle(
        pos:    center,
        vel:    Offset(cos(angle) * speed, sin(angle) * speed),
        color:  colors[rng.nextInt(colors.length)],
        radius: 7 + rng.nextDouble() * 9,   // bigger: 7–16px
        opacity: 1.0,
        shape:  i % 3,
      );
    });

    return ParticleBurstPainter._(
      progress: progress,
      center:   center,
      particles: particles,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final t = Curves.easeOut.transform(progress);
    // Fade only in last 25% so particles are fully visible longer
    final opacity = progress < 0.75 ? 1.0 : 1.0 - ((progress - 0.75) / 0.25);

    for (final p in _particles) {
      final pos      = p.pos + p.vel * t;
      final droopY   = 80 * t * t; // gravity
      final drawPos  = Offset(pos.dx, pos.dy + droopY);
      final curSize  = p.radius * (1.0 - t * 0.2); // barely shrink
      final alpha    = (opacity * p.opacity).clamp(0.0, 1.0);
      final paint    = Paint()
        ..color = p.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      switch (p.shape) {
        case 0: // circle
          canvas.drawCircle(drawPos, curSize, paint);
          break;
        case 1: // rotating diamond
          canvas.save();
          canvas.translate(drawPos.dx, drawPos.dy);
          canvas.rotate(pi / 4 + t * 2 * pi);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero,
                width: curSize * 1.6, height: curSize * 1.6),
            paint,
          );
          canvas.restore();
          break;
        case 2: // 5-pointed star
          canvas.save();
          canvas.translate(drawPos.dx, drawPos.dy);
          canvas.rotate(t * 2 * pi);
          canvas.drawPath(_starPath(curSize * 1.3), paint);
          canvas.restore();
          break;
      }
    }
  }

  /// Builds a 5-pointed star path centred at origin with outer radius [r].
  Path _starPath(double r) {
    const points = 5;
    final inner  = r * 0.45;
    final path   = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle  = (i * pi / points) - pi / 2;
      final radius = i.isEven ? r : inner;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(ParticleBurstPainter old) => old.progress != progress;
}