import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget destination;
  const SplashScreen({super.key, required this.destination});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _iconOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _loadingOpacity;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _iconOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.6, 0.8, curve: Curves.easeIn),
      ),
    );

    _loadingOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    _fadeController.forward();
    _navigateToDestination();
  }

  Future<void> _navigateToDestination() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.destination,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        AppTheme.brandDefault.withValues(alpha: 0.1),
                        const Color(0xFF0f0f0f),
                      ]
                    : [
                        AppTheme.brandDefault.withValues(alpha: 0.05),
                        Colors.white,
                      ],
              ),
            ),
            child: Stack(
              children: [
                // Subtle background pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03,
                    child: CustomPaint(
                      painter: _FinancePatternPainter(),
                    ),
                  ),
                ),
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon with fade and scale
                      Opacity(
                        opacity: _iconOpacity.value,
                        child: Transform.scale(
                          scale: 0.8 + (_iconOpacity.value * 0.2),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.brandDefault,
                                  AppTheme.brandLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(30)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(0, 123, 85, 0.3),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // App Name with fade
                      Opacity(
                        opacity: _textOpacity.value,
                        child: Text(
                          'FinFlow',
                          style: GoogleFonts.poppins(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Dot
                      Opacity(
                        opacity: _textOpacity.value,
                        child: Text(
                          '.',
                          style: GoogleFonts.poppins(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandDefault,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tagline with fade
                      Opacity(
                        opacity: _taglineOpacity.value,
                        child: Text(
                          'Master Your Finances',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Loading Indicator with fade
                      Opacity(
                        opacity: _loadingOpacity.value,
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandDefault),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: _loadingOpacity.value,
                        child: Text(
                          'Loading...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FinancePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle grid lines
    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw subtle currency symbols
    final textPainter = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: Colors.grey.withValues(alpha: 0.05),
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        textPainter.layout();
        final x = (size.width / 6) * (i + 1);
        final y = (size.height / 6) * (j + 1);
        textPainter.paint(canvas, Offset(x - 10, y - 10));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
