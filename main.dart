import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  MOCK DATA – single source of truth for the entire app
// ─────────────────────────────────────────────────────────────
class AppData {
  static const Map<String, dynamic> state = {
    "route": {
      "pickup": "Koramangala, Block 5",
      "dropoff": "MG Road Metro Station",
      "distance": "6.2 km",
    },
    "surge_status": "HIGH",
    "ai_prediction": "Wait 12 mins. Uber prices drop by ₹60.",
    "rides": [
      {
        "platform": "Rapido",
        "price": 140,
        "eta": "4 min",
        "tag": "Cheapest",
        "color": "0xFF06D6A0",
      },
      {
        "platform": "Namma Yatri",
        "price": 150,
        "eta": "2 min",
        "tag": "Fastest",
        "color": "0xFF06D6A0",
      },
      {
        "platform": "Ola",
        "price": 265,
        "eta": "5 min",
        "tag": "Surging",
        "color": "0xFFFFD166",
      },
      {
        "platform": "Uber",
        "price": 280,
        "eta": "7 min",
        "tag": "High Demand",
        "color": "0xFFFF4D6D",
      },
    ],
  };

  static Map<String, String> get route =>
      Map<String, String>.from(state['route'] as Map);
  static String get surgeStatus => state['surge_status'] as String;
  static String get aiPrediction => state['ai_prediction'] as String;
  static List<Map<String, dynamic>> get rides =>
      List<Map<String, dynamic>>.from(state['rides'] as List);
}

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS — premium dark-mode palette
// ─────────────────────────────────────────────────────────────
class Tok {
  // Surfaces
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF111118);
  static const Color surfaceHigh = Color(0xFF1A1A24);
  static const Color surfaceBright = Color(0xFF24243A);

  // Accents
  static const Color accent = Color(0xFF7C5CFC); // purple-indigo accent
  static const Color accentGlow = Color(0xFF9B7DFF);
  static const Color neon = Color(0xFF06D6A0); // green neon
  static const Color neonDim = Color(0xFF04A67C);
  static const Color amber = Color(0xFFFFD166);
  static const Color danger = Color(0xFFFF4D6D);

  // Text
  static const Color textPrimary = Color(0xFFF0EFF4);
  static const Color textSecondary = Color(0xFF9896A3);
  static const Color textMuted = Color(0xFF5C5A66);

  // Misc
  static const double radius = 20;
  static const double radiusSm = 12;
  static const double radiusXs = 8;

  // Glassmorphism helpers
  static BoxDecoration glass({
    Color? borderColor,
    double borderOpacity = 0.08,
    double bgOpacity = 0.06,
    double blurRadius = 24,
    double cornerRadius = radius,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(bgOpacity),
      borderRadius: BorderRadius.circular(cornerRadius),
      border: Border.all(
        color: (borderColor ?? Colors.white).withOpacity(borderOpacity),
        width: 1,
      ),
    );
  }

  static BoxDecoration glassNeon({double cornerRadius = radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          neon.withOpacity(0.08),
          neon.withOpacity(0.02),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(cornerRadius),
      border: Border.all(color: neon.withOpacity(0.35), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: neon.withOpacity(0.10),
          blurRadius: 30,
          spreadRadius: 2,
        ),
      ],
    );
  }

  static BoxDecoration glassAccent({double cornerRadius = radius}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          accent.withOpacity(0.12),
          accent.withOpacity(0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(cornerRadius),
      border: Border.all(color: accent.withOpacity(0.30), width: 1),
      boxShadow: [
        BoxShadow(
          color: accent.withOpacity(0.08),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MAIN ENTRY POINT
// ─────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Tok.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const RideAggApp());
}

class RideAggApp extends StatelessWidget {
  const RideAggApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideAgg',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Tok.bg,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.dark(
          surface: Tok.bg,
          primary: Tok.accent,
          secondary: Tok.neon,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CUSTOM PAGE ROUTE – smooth slide + fade
// ─────────────────────────────────────────────────────────────
class _SlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  _SlideRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SCREEN 1 — HomeScreen (Search Entry)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _loading = false;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _fadeInController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );
    _fadeInController.forward();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  void _onCompare() {
    setState(() => _loading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.push(context, _SlideRoute(page: const ResultsScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = AppData.route;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient orbs
          _BackgroundOrbs(),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Top bar
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Tok.accent,
                                Tok.neon,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'R',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RideAgg',
                              style: TextStyle(
                                color: Tok.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Powered by ONDC',
                              style: TextStyle(
                                color: Tok.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: Tok.glass(
                            borderColor: Tok.neon,
                            borderOpacity: 0.25,
                            bgOpacity: 0.08,
                            cornerRadius: 20,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Tok.neon,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Tok.neon,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 2),

                    // Hero section
                    Text(
                      'Where are\nyou headed?',
                      style: TextStyle(
                        color: Tok.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compare prices across all platforms in one tap.',
                      style: TextStyle(
                        color: Tok.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Route card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Tok.radius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          decoration: Tok.glass(bgOpacity: 0.07),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _LocationRow(
                                icon: Icons.radio_button_checked,
                                iconColor: Tok.neon,
                                label: 'PICKUP',
                                value: route['pickup']!,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 11, right: 11),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 1.5,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Tok.neon.withOpacity(0.5),
                                            Tok.danger.withOpacity(0.5),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _LocationRow(
                                icon: Icons.location_on_rounded,
                                iconColor: Tok.danger,
                                label: 'DROPOFF',
                                value: route['dropoff']!,
                              ),
                              const SizedBox(height: 16),
                              // Distance pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: Tok.glass(
                                  bgOpacity: 0.06,
                                  cornerRadius: 20,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.straighten_rounded,
                                        color: Tok.textSecondary, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      route['distance']!,
                                      style: const TextStyle(
                                        color: Tok.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Tok.accent, Color(0xFF6341E0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Tok.accent.withOpacity(0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _onCompare,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.compare_arrows_rounded,
                                  color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              const Text(
                                'Compare Prices',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Bottom micro-copy
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Scanning Uber · Ola · Rapido · Namma Yatri',
                          style: TextStyle(
                            color: Tok.textMuted.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_loading) _ScanningOverlay(shimmerController: _shimmerController),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Background animated gradient orbs
// ─────────────────────────────────────────────────────────────
class _BackgroundOrbs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Tok.accent.withOpacity(0.12),
                  Tok.accent.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -100,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Tok.neon.withOpacity(0.06),
                  Tok.neon.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 300,
          left: 200,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Tok.danger.withOpacity(0.06),
                  Tok.danger.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Location row widget
// ─────────────────────────────────────────────────────────────
class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Tok.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Tok.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Scanning overlay with shimmer
// ─────────────────────────────────────────────────────────────
class _ScanningOverlay extends StatelessWidget {
  final AnimationController shimmerController;
  const _ScanningOverlay({required this.shimmerController});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tok.bg.withOpacity(0.92),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated rings
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: shimmerController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ScanRingsPainter(shimmerController.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              // Shimmer text
              AnimatedBuilder(
                animation: shimmerController,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: const [
                          Tok.textMuted,
                          Tok.textPrimary,
                          Tok.neon,
                          Tok.textPrimary,
                          Tok.textMuted,
                        ],
                        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                        begin: Alignment(-1.0 + 2.0 * shimmerController.value,
                            0),
                        end: Alignment(
                            1.0 + 2.0 * shimmerController.value, 0),
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'Scanning ONDC rails &\naggregator platforms...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Progress dots
              SizedBox(
                width: 60,
                child: AnimatedBuilder(
                  animation: shimmerController,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final phase = (shimmerController.value + i * 0.3) % 1.0;
                        final opacity = 0.3 + 0.7 * sin(phase * pi);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Tok.accent.withOpacity(opacity),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanRingsPainter extends CustomPainter {
  final double progress;
  _ScanRingsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final radius = 20.0 + phase * 40.0;
      final opacity = (1.0 - phase) * 0.5;
      final paint = Paint()
        ..color = Tok.accent.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius, paint);
    }
    // Center dot
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Tok.accent
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanRingsPainter old) => true;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SCREEN 2 — ResultsScreen (The Aggregator Matrix)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _staggerController;
  late List<Animation<double>> _tileAnimations;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final rides = AppData.rides;
    _tileAnimations = List.generate(rides.length, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _staggerController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  String _platformEmoji(String platform) {
    switch (platform) {
      case 'Rapido':
        return '⚡';
      case 'Namma Yatri':
        return '🛺';
      case 'Ola':
        return '🚕';
      case 'Uber':
        return '🚗';
      default:
        return '🚘';
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = AppData.route;
    final rides = AppData.rides;
    final aiPrediction = AppData.aiPrediction;

    return Scaffold(
      body: Stack(
        children: [
          _BackgroundOrbs(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: Tok.glass(cornerRadius: 12),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Tok.textPrimary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Koramangala ➔ MG Road',
                              style: const TextStyle(
                                color: Tok.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${route['distance']} · ${rides.length} platforms found',
                              style: const TextStyle(
                                color: Tok.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Surge badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Tok.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Tok.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.trending_up_rounded,
                                color: Tok.danger, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'HIGH',
                              style: TextStyle(
                                color: Tok.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SizedBox(height: 8),

                      // AI Insight Card
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          final glowOpacity =
                              0.08 + 0.06 * sin(_glowController.value * pi);
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Tok.neon.withOpacity(glowOpacity + 0.04),
                                  Tok.neon.withOpacity(glowOpacity * 0.3),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(Tok.radius),
                              border: Border.all(
                                color: Tok.neon.withOpacity(
                                    0.25 + 0.15 * sin(_glowController.value * pi)),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Tok.neon.withOpacity(glowOpacity),
                                  blurRadius: 40,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(Tok.radius),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 16, sigmaY: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Tok.neon.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: Text('🧠',
                                              style:
                                                  TextStyle(fontSize: 22)),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'AI Surge Insight',
                                              style: TextStyle(
                                                color: Tok.neon,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              aiPrediction,
                                              style: const TextStyle(
                                                color: Tok.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Section label
                      Row(
                        children: [
                          Text(
                            'AVAILABLE RIDES',
                            style: TextStyle(
                              color: Tok.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Sorted by price',
                            style: TextStyle(
                              color: Tok.textMuted.withOpacity(0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Ride tiles (staggered)
                      ...List.generate(rides.length, (index) {
                        final ride = rides[index];
                        final tagColor =
                            Color(int.parse(ride['color'] as String));
                        final isRapido = ride['platform'] == 'Rapido';
                        final isBest = index == 0;

                        Widget tile = FadeTransition(
                          opacity: _tileAnimations[index],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(_tileAnimations[index]),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: isBest
                                  ? Tok.glassAccent()
                                  : Tok.glass(bgOpacity: 0.05),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(Tok.radius),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 16, sigmaY: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 16),
                                    child: Row(
                                      children: [
                                        // Platform icon + name
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: tagColor.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _platformEmoji(
                                                  ride['platform'] as String),
                                              style: const TextStyle(
                                                  fontSize: 24),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ride['platform'] as String,
                                                style: const TextStyle(
                                                  color: Tok.textPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .access_time_rounded,
                                                      color:
                                                          Tok.textSecondary,
                                                      size: 13),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    ride['eta'] as String,
                                                    style: const TextStyle(
                                                      color:
                                                          Tok.textSecondary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  // Tag pill
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: tagColor
                                                          .withOpacity(0.15),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(20),
                                                      border: Border.all(
                                                        color: tagColor
                                                            .withOpacity(
                                                                0.30),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      ride['tag'] as String,
                                                      style: TextStyle(
                                                        color: tagColor,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Price
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${ride['price']}',
                                              style: TextStyle(
                                                color: isBest
                                                    ? Tok.neon
                                                    : Tok.textPrimary,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -1,
                                              ),
                                            ),
                                            if (isBest)
                                              Text(
                                                'BEST PRICE',
                                                style: TextStyle(
                                                  color: Tok.neon
                                                      .withOpacity(0.7),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (isRapido) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Tok.accent.withOpacity(0.6),
                                            size: 16,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );

                        if (isRapido) {
                          tile = GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              _SlideRoute(page: const SuccessScreen()),
                            ),
                            child: tile,
                          );
                        }

                        return tile;
                      }),

                      const SizedBox(height: 16),

                      // Bottom ONDC attribution
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: Tok.glass(
                            bgOpacity: 0.04,
                            cornerRadius: 20,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: Tok.neon.withOpacity(0.6), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Prices verified via ONDC Network',
                                style: TextStyle(
                                  color: Tok.textMuted.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SCREEN 3 — SuccessScreen (The ONDC Confirmation)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _BackgroundOrbs(),

          // Central radial glow
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final opacity =
                    0.08 + 0.06 * sin(_pulseController.value * pi);
                return Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Tok.neon.withOpacity(opacity),
                        Tok.neon.withOpacity(0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Top bar
                  Row(
                    children: [
                      const Text(
                        'RideAgg',
                        style: TextStyle(
                          color: Tok.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: Tok.glass(
                          borderColor: Tok.neon,
                          borderOpacity: 0.25,
                          bgOpacity: 0.08,
                          cornerRadius: 20,
                        ),
                        child: const Text(
                          'CONFIRMED',
                          style: TextStyle(
                            color: Tok.neon,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Checkmark animation
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale =
                            1.0 + 0.06 * sin(_pulseController.value * pi);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Tok.neon,
                                  Tok.neonDim,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Tok.neon.withOpacity(0.30),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Headline
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        const Text(
                          'Ride Confirmed\nvia ONDC Network',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Tok.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your Rapido captain is arriving in 4 mins.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Tok.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Trip details mini-card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tok.radius),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              decoration: Tok.glass(bgOpacity: 0.05),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  const Text('⚡',
                                      style: TextStyle(fontSize: 28)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Rapido Bike',
                                          style: TextStyle(
                                            color: Tok.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Koramangala ➔ MG Road · 6.2 km',
                                          style: TextStyle(
                                            color: Tok.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    '₹140',
                                    style: TextStyle(
                                      color: Tok.neon,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Savings card (The Closing Hook)
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Tok.accent.withOpacity(0.14),
                            Tok.neon.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(Tok.radius),
                        border: Border.all(
                          color: Tok.accent.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Tok.radius),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Tok.neon.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Text('🎉',
                                        style: TextStyle(fontSize: 24)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Smart Move!',
                                        style: TextStyle(
                                          color: Tok.neon,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Tok.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                          children: [
                                            const TextSpan(
                                                text: 'You saved '),
                                            TextSpan(
                                              text: '₹140',
                                              style: TextStyle(
                                                color: Tok.neon,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const TextSpan(
                                              text:
                                                  ' on this trip by using RideAgg.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Done button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Tok.textMuted.withOpacity(0.25),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Tok.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
