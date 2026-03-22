import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'widgets/panda_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puzzle World',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFF8FAB),
        useMaterial3:    true,
      ),
      home: const _SplashScreen(),
    );
  }
}

// ── Splash / loading screen shown on first app launch ────────────────────────

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _runProgress();
  }

  Future<void> _runProgress() async {
    for (final step in [0.15, 0.45, 0.75, 1.0]) {
      await Future.delayed(const Duration(milliseconds: 180));
      if (mounted) setState(() => _progress = step);
    }
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD6E0),
      body: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          final barW    = constraints.maxWidth * 0.48;
          const pandaSz = 72.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App title
              Text('🧩 Puzzle World',
                style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w800,
                  color: const Color(0xFF9B4B6B),
                  shadows: [Shadow(color: Colors.white.withOpacity(0.6),
                      offset: const Offset(1, 2), blurRadius: 6)],
                )),
              const SizedBox(height: 40),

              // Panda + progress bar
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: pandaSz, height: pandaSz,
                    child: PandaWidget(size: pandaSz)),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: barW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Loading...',
                          style: TextStyle(fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9B6B7A),
                              letterSpacing: 1.1)),
                        const SizedBox(height: 10),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: _progress),
                          duration: const Duration(milliseconds: 260),
                          builder: (_, value, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 20,
                                  child: LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white54,
                                    valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFFFF6B9D))),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text('${(value * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12,
                                    color: Color(0xFF9B6B7A),
                                    fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}