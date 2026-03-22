import 'dart:math';
import 'package:flutter/material.dart';

/// Sparkle border — random glints at corners and edges, like sunlight on glass.
/// No rotating arc. Instead: multiple independent sparkle points that
/// flash, fade, and reappear at random positions along the border.
class LightningBorder extends StatefulWidget {
  final Widget  child;
  final double  borderRadius;
  final Color   color;
  final Color   color2;
  final double  strokeWidth;
  final Duration duration;

  const LightningBorder({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.color        = const Color(0xFFFFE44D),
    this.color2       = const Color(0xFFFFFFFF),
    this.strokeWidth  = 3.0,
    this.duration     = const Duration(milliseconds: 2400),
  });

  @override
  State<LightningBorder> createState() => _LightningBorderState();
}

class _LightningBorderState extends State<LightningBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Sparkle> _sparkles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _sparkles = List.generate(12, (i) => _Sparkle.random(_rng, i));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50), // fast tick
    )..repeat();
    _ctrl.addListener(_tick);
  }

  void _tick() {
    for (final s in _sparkles) {
      s.update(0.016); // ~60fps delta
    }
    // Respawn dead sparkles
    for (int i = 0; i < _sparkles.length; i++) {
      if (_sparkles[i].dead) {
        _sparkles[i] = _Sparkle.random(_rng, i);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, child) => CustomPaint(
      foregroundPainter: _SparklePainter(
        sparkles:    _sparkles,
        radius:      widget.borderRadius,
        color:       widget.color,
        color2:      widget.color2,
        strokeWidth: widget.strokeWidth,
      ),
      child: child,
    ),
    child: widget.child,
  );
}

// ── Sparkle data ──────────────────────────────────────────────────────────────

class _Sparkle {
  /// Position along the perimeter as a fraction 0..1
  double perimFrac;
  /// Current opacity 0..1
  double opacity;
  /// Max opacity this sparkle will reach
  double maxOpacity;
  /// Is it fading in (true) or out (false)?
  bool   rising;
  /// Speed of fade in/out
  double speed;
  /// Size multiplier
  double size;
  /// Hue shift (0=color, 1=color2)
  double hue;
  /// Star vs circle
  bool   isStar;

  _Sparkle({
    required this.perimFrac,
    required this.opacity,
    required this.maxOpacity,
    required this.rising,
    required this.speed,
    required this.size,
    required this.hue,
    required this.isStar,
  });

  factory _Sparkle.random(Random rng, int seed) {
    // Bias positions toward corners: corners are at ~0, 0.25, 0.5, 0.75
    // Add slight random offset so they cluster near corners/edges
    final corner = (seed % 4) / 4.0;
    final offset = (rng.nextDouble() - 0.5) * 0.18;
    return _Sparkle(
      perimFrac:  (corner + offset + 1.0) % 1.0,
      opacity:    0,
      maxOpacity: 0.55 + rng.nextDouble() * 0.45,
      rising:     true,
      speed:      0.6 + rng.nextDouble() * 1.2,
      size:       0.6 + rng.nextDouble() * 1.4,
      hue:        rng.nextDouble(),
      isStar:     rng.nextDouble() > 0.4,
    );
  }

  bool get dead => !rising && opacity <= 0;

  void update(double dt) {
    if (rising) {
      opacity += speed * dt;
      if (opacity >= maxOpacity) {
        opacity = maxOpacity;
        rising  = false;
      }
    } else {
      opacity -= speed * dt * 0.7; // fade out slightly slower
      if (opacity < 0) opacity = 0;
    }
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final double  radius;
  final Color   color;
  final Color   color2;
  final double  strokeWidth;

  const _SparklePainter({
    required this.sparkles,
    required this.radius,
    required this.color,
    required this.color2,
    required this.strokeWidth,
  });

  Color _lerp(double t) => Color.lerp(color, color2, t)!;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius.clamp(0.0, min(size.width, size.height) / 2);

    // Build border path to sample positions from
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(r)));
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.first.length;

    // Draw subtle base border glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(r)),
      Paint()
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.6
        ..color       = color.withOpacity(0.20)
        ..maskFilter  = MaskFilter.blur(BlurStyle.normal, 4),
    );

    for (final s in sparkles) {
      if (s.opacity <= 0.01) continue;

      final pos = s.perimFrac * total;
      final tang = metrics.first.getTangentForOffset(pos.clamp(0, total));
      if (tang == null) continue;

      final c    = _lerp(s.hue);
      final pt   = tang.position;
      final sz   = strokeWidth * s.size;

      if (s.isStar) {
        _drawStar(canvas, pt, sz, c, s.opacity);
      } else {
        _drawGlint(canvas, pt, sz, c, s.opacity);
      }
    }
  }

  /// 4-pointed star / cross glint — like sunlight on a mirror
  void _drawStar(Canvas canvas, Offset center, double size, Color c, double opacity) {
    // Outer halo
    canvas.drawCircle(center, size * 2.5,
      Paint()
        ..color      = c.withOpacity(opacity * 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 1.5));

    // Draw 4-point star
    final path = Path();
    const arms = 4;
    for (int i = 0; i < arms * 2; i++) {
      final angle  = (i * pi / arms);
      final radius = i.isEven ? size * 2.2 : size * 0.4;
      final x      = center.dx + cos(angle) * radius;
      final y      = center.dy + sin(angle) * radius;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();

    // Glow fill
    canvas.drawPath(path,
      Paint()
        ..color      = c.withOpacity(opacity * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size));

    // Bright fill
    canvas.drawPath(path,
      Paint()..color = c.withOpacity(opacity * 0.80));

    // White hot centre dot
    canvas.drawCircle(center, size * 0.5,
      Paint()..color = Colors.white.withOpacity(opacity));
  }

  /// Simple circular glint — smaller accent sparkle
  void _drawGlint(Canvas canvas, Offset center, double size, Color c, double opacity) {
    canvas.drawCircle(center, size * 2.0,
      Paint()
        ..color      = c.withOpacity(opacity * 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 1.2));
    canvas.drawCircle(center, size * 0.9,
      Paint()..color = Colors.white.withOpacity(opacity * 0.90));
  }

  @override
  bool shouldRepaint(_SparklePainter old) => true;
}